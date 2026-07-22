// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface ITokenMessengerV2MS {
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

/// @notice OTC multi-stable / ETH rail. Desk pays DAI · USDT · USDC · WETH; Kingdom pays RSS.
/// @dev Default: assets → Landing on Base. USDC can CCTP → Ethereum (domain 0).
///      Native ETH: receive() / fillEth() → Landing.
///      Min $500k notional (6dp stables / 18dp WETH·ETH at oracle $1 WETH needs separate quote — see fillWeth).
contract CrownMultiStableRail is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint8 public constant SETTLE_BASE = 1;
    uint8 public constant SETTLE_ETH_CCTP = 2; // USDC only
    uint32 public constant ETH_DOMAIN = 0;
    uint256 public constant MIN_STABLE_6 = 500_000e6;
    uint256 public constant MIN_WETH_18 = 200 ether; // ~$500k @ $2500 — desk quotes exact

    IERC20 public immutable dai;
    IERC20 public immutable usdt;
    IERC20 public immutable usdc;
    IERC20 public immutable weth;
    IERC20 public immutable rss;
    ITokenMessengerV2MS public immutable tokenMessenger;
    address public immutable landing;

    uint256 public rssStock;
    uint256 public raisedDai;
    uint256 public raisedUsdt;
    uint256 public raisedUsdc;
    uint256 public raisedWeth;
    uint256 public raisedEth;
    uint32 public minFinalityThreshold = 2000;
    uint256 public maxCctpFee;

    mapping(address => bool) public stableOk; // 6-decimal stables at $1 peg

    event StockedRss(uint256 amt);
    event FilledStable(address indexed desk, address token, uint256 amt, uint256 rssOut, uint8 settle);
    event FilledWeth(address indexed desk, uint256 wethIn, uint256 rssOut);
    event FilledEth(address indexed desk, uint256 ethIn, uint256 rssOut);

    error BadAmt();
    error BadToken();
    error Empty();
    error LandingMiss();

    constructor(
        address dai_,
        address usdt_,
        address usdc_,
        address weth_,
        address rss_,
        address tokenMessenger_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        if (landing_ == address(0)) revert BadAmt();
        dai = IERC20(dai_);
        usdt = IERC20(usdt_);
        usdc = IERC20(usdc_);
        weth = IERC20(weth_);
        rss = IERC20(rss_);
        tokenMessenger = ITokenMessengerV2MS(tokenMessenger_);
        landing = landing_;
        stableOk[dai_] = true;
        stableOk[usdt_] = true;
        stableOk[usdc_] = true;
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

    function unstockRss(uint256 amt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = owner;
        if (amt == 0 || amt > rssStock) revert BadAmt();
        rssStock -= amt;
        rss.safeTransfer(to, amt);
    }

    /// @notice Desk pays DAI/USDT/USDC (6dp). rssOut = amt * 1e12 ($1 peg).
    /// @param settle SETTLE_BASE=1 all tokens → Landing Base; SETTLE_ETH_CCTP=2 USDC only → ETH mint.
    function fillStable(address token, uint256 amt, uint256 rssOut, uint8 settle) external nonReentrant {
        if (!stableOk[token]) revert BadToken();
        if (amt < MIN_STABLE_6) revert BadAmt();
        if (rssOut != amt * 1e12) revert BadAmt();
        if (rssOut > rssStock) revert Empty();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);
        rssStock -= rssOut;

        if (token == address(dai)) raisedDai += amt;
        else if (token == address(usdt)) raisedUsdt += amt;
        else raisedUsdc += amt;

        if (settle == SETTLE_ETH_CCTP) {
            if (token != address(usdc)) revert BadToken();
            usdc.safeApprove(address(tokenMessenger), amt);
            tokenMessenger.depositForBurn(
                amt,
                ETH_DOMAIN,
                bytes32(uint256(uint160(landing))),
                address(usdc),
                bytes32(0),
                maxCctpFee,
                minFinalityThreshold
            );
        } else if (settle == SETTLE_BASE) {
            uint256 before = IERC20(token).balanceOf(landing);
            IERC20(token).safeTransfer(landing, amt);
            if (IERC20(token).balanceOf(landing) < before + amt) revert LandingMiss();
        } else {
            revert BadAmt();
        }

        rss.safeTransfer(msg.sender, rssOut);
        emit FilledStable(msg.sender, token, amt, rssOut, settle);
    }

    /// @notice Desk pays WETH. King sets rssOut (desk-quoted). Min 200 WETH notional gate.
    function fillWeth(uint256 wethIn, uint256 rssOut) external nonReentrant {
        if (wethIn < MIN_WETH_18) revert BadAmt();
        if (rssOut == 0 || rssOut > rssStock) revert Empty();

        weth.safeTransferFrom(msg.sender, address(this), wethIn);
        raisedWeth += wethIn;
        rssStock -= rssOut;

        uint256 before = weth.balanceOf(landing);
        weth.safeTransfer(landing, wethIn);
        if (weth.balanceOf(landing) < before + wethIn) revert LandingMiss();

        rss.safeTransfer(msg.sender, rssOut);
        emit FilledWeth(msg.sender, wethIn, rssOut);
    }

    /// @notice Desk sends native ETH with rssOut encoded… use fillEth(rssOut) payable.
    function fillEth(uint256 rssOut) external payable nonReentrant {
        if (msg.value < MIN_WETH_18) revert BadAmt();
        if (rssOut == 0 || rssOut > rssStock) revert Empty();

        raisedEth += msg.value;
        rssStock -= rssOut;

        (bool ok,) = landing.call{value: msg.value}("");
        require(ok, "ETH_LAND");

        rss.safeTransfer(msg.sender, rssOut);
        emit FilledEth(msg.sender, msg.value, rssOut);
    }

    function quote()
        external
        view
        returns (uint256 minStable6, uint256 minEthWei, uint256 rssAvail, address land)
    {
        return (MIN_STABLE_6, MIN_WETH_18, rssStock, landing);
    }

    receive() external payable {
        revert BadAmt(); // force fillEth(rssOut)
    }
}
