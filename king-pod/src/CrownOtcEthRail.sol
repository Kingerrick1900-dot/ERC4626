// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface ITokenMessengerV2 {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external returns (uint64 nonce);
}

/// @notice OTC desk fill → Ethereum. Desk pays USDC; Kingdom pays RSS (or kUSD).
/// @dev MODE_ETH: burn USDC via CCTP V2 → mint to Landing on Ethereum (domain 0).
///      MODE_BASE: USDC straight to Landing on Base.
///      LAW: fill reverts unless USDC leaves to Landing rail (Base transfer or CCTP burn).
///      Proven pattern: Wintermute $200M principal block · Kraken/Maple $500k min loans · CCTP $20B+/mo.
contract CrownOtcEthRail is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint8 public constant MODE_BASE = 1;
    uint8 public constant MODE_ETH = 2;
    uint32 public constant ETH_DOMAIN = 0;
    uint256 public constant MIN_FILL = 500_000e6; // $500k floor — desk ticket, not dust

    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IERC20 public immutable kusd;
    ITokenMessengerV2 public immutable tokenMessenger;
    address public immutable landing; // EOA — same addr receives USDC on ETH after CCTP mint

    uint256 public rssStock;
    uint256 public kusdStock;
    uint256 public raisedUsdc;
    uint256 public bridgedUsdc;
    uint32 public minFinalityThreshold = 2000;
    uint256 public maxCctpFee;

    event StockedRss(uint256 amt);
    event StockedKusd(uint256 amt);
    event FilledBase(address indexed desk, uint256 usdcIn, uint256 rssOut, uint256 kusdOut);
    event FilledEth(address indexed desk, uint256 usdcIn, uint256 rssOut, uint256 kusdOut, uint64 cctpNonce);

    error BadAmt();
    error Empty();
    error BadMode();
    error LandingMiss();

    constructor(
        address usdc_,
        address rss_,
        address kusd_,
        address tokenMessenger_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        if (landing_ == address(0)) revert BadAmt();
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        kusd = IERC20(kusd_);
        tokenMessenger = ITokenMessengerV2(tokenMessenger_);
        landing = landing_;
    }

    function setCctpParams(uint32 minFinality, uint256 maxFee) external onlyOwner {
        minFinalityThreshold = minFinality;
        maxCctpFee = maxFee;
    }

    function stockRss(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), amt);
        rssStock += amt;
        emit StockedRss(amt);
    }

    function stockKusd(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        kusd.safeTransferFrom(msg.sender, address(this), amt);
        kusdStock += amt;
        emit StockedKusd(amt);
    }

    function unstockRss(uint256 amt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = owner;
        if (amt == 0 || amt > rssStock) revert BadAmt();
        rssStock -= amt;
        rss.safeTransfer(to, amt);
    }

    function unstockKusd(uint256 amt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = owner;
        if (amt == 0 || amt > kusdStock) revert BadAmt();
        kusdStock -= amt;
        kusd.safeTransfer(to, amt);
    }

    /// @notice Desk fill. 1 USDC → 1 RSS (18dp) and/or 1 kUSD (6dp) from stock.
    /// @param usdcAmt USDC 6dp — minimum $500k
    /// @param rssOut RSS wei to desk (0 ok if kusdOut > 0)
    /// @param kusdOut kUSD 6dp to desk (0 ok if rssOut > 0)
    /// @param mode MODE_BASE (1) or MODE_ETH CCTP (2)
    function fill(uint256 usdcAmt, uint256 rssOut, uint256 kusdOut, uint8 mode) external nonReentrant {
        if (usdcAmt < MIN_FILL) revert BadAmt();
        if (rssOut == 0 && kusdOut == 0) revert BadAmt();
        if (rssOut > rssStock) revert Empty();
        if (kusdOut > kusdStock) revert Empty();
        // Peg: $1 RSS (1e18) per $1 USDC (1e6); kUSD 1:1 raw
        if (rssOut > 0 && rssOut != usdcAmt * 1e12) revert BadAmt();
        if (kusdOut > 0 && kusdOut != usdcAmt) revert BadAmt();
        // Don't double-pay full notional in both unless desk wants split — require sum value == usdc
        if (rssOut > 0 && kusdOut > 0) revert BadAmt();

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        raisedUsdc += usdcAmt;
        rssStock -= rssOut;
        kusdStock -= kusdOut;

        if (mode == MODE_BASE) {
            uint256 before = usdc.balanceOf(landing);
            usdc.safeTransfer(landing, usdcAmt);
            if (usdc.balanceOf(landing) < before + usdcAmt) revert LandingMiss();
            if (rssOut > 0) rss.safeTransfer(msg.sender, rssOut);
            if (kusdOut > 0) kusd.safeTransfer(msg.sender, kusdOut);
            emit FilledBase(msg.sender, usdcAmt, rssOut, kusdOut);
            return;
        }

        if (mode != MODE_ETH) revert BadMode();

        // CCTP V2: burn on Base → mint USDC to Landing on Ethereum
        usdc.safeApprove(address(tokenMessenger), usdcAmt);
        bytes32 mintRecipient = bytes32(uint256(uint160(landing)));
        uint64 nonce = tokenMessenger.depositForBurn(
            usdcAmt,
            ETH_DOMAIN,
            mintRecipient,
            address(usdc),
            bytes32(0),
            maxCctpFee,
            minFinalityThreshold
        );
        bridgedUsdc += usdcAmt;

        if (rssOut > 0) rss.safeTransfer(msg.sender, rssOut);
        if (kusdOut > 0) kusd.safeTransfer(msg.sender, kusdOut);

        emit FilledEth(msg.sender, usdcAmt, rssOut, kusdOut, nonce);
    }

    function quote()
        external
        view
        returns (uint256 minFill, uint256 rssAvail, uint256 kusdAvail, address ethMintTo, uint32 ethDomain)
    {
        return (MIN_FILL, rssStock, kusdStock, landing, ETH_DOMAIN);
    }
}
