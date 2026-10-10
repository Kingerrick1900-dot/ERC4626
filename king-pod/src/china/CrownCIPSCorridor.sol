// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IOpenMoney {
    function createInvoice(bytes32 id, address merchant, address payer, uint256 amount) external;
    function payInvoice(bytes32 id) external;
    function merchant(address) external view returns (bool);
}

interface IBorders {
    function bordersSecure() external view returns (bool);
}

/// @title CrownCIPSCorridor
/// @notice CIPS-*corridor* adapter: invoice → eUSD capture → USDC settle to beneficiary.
/// @dev Not a live PBOC CIPS socket. Crown Open Money path with stable out-leg for CN desk.
contract CrownCIPSCorridor is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    IERC20 public immutable usdc;
    address public openMoney;
    address public attest;
    address public desk; // CN desk operator

    /// @dev eUSD(18)→USDC(6): usdcOut = eusdIn * rateUsdcPerEusd / 1e18
    ///      Default 1e6 ⇒ $1 eUSD → 1e6 raw USDC (1:1 USD).
    uint256 public rateUsdcPerEusd = 1e6;
    uint256 public usdcLiquidity; // desk-prefunded USDC for settles

    struct CorridorTx {
        bytes32 invoiceId;
        address merchant;
        address payer;
        address beneficiary; // USDC recipient (desk / KingVault)
        uint256 eusdAmount;
        uint256 usdcAmount;
        uint8 status; // 0 none, 1 invoiced, 2 eusdPaid, 3 usdcSettled
    }

    mapping(bytes32 => CorridorTx) public txs; // corridorId

    event DeskSet(address desk);
    event RateSet(uint256 rateUsdcPerEusd);
    event UsdcFunded(uint256 amt, uint256 liquidity);
    event CorridorOpened(bytes32 indexed corridorId, bytes32 invoiceId, address merchant, address payer, uint256 eusdAmount);
    event EusdCaptured(bytes32 indexed corridorId, uint256 eusdAmount);
    event UsdcSettled(bytes32 indexed corridorId, address beneficiary, uint256 usdcAmount);

    error Auth();
    error Bad();
    error Borders();
    error Liquidity();
    error Status();

    modifier onlyDesk() {
        if (msg.sender != desk && msg.sender != owner) revert Auth();
        _;
    }

    constructor(address eusd_, address usdc_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0) && usdc_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
    }

    function setModules(address openMoney_, address attest_, address desk_) external onlyOwner {
        openMoney = openMoney_;
        attest = attest_;
        desk = desk_;
        emit DeskSet(desk_);
    }

    function setRate(uint256 rateUsdcPerEusd_) external onlyOwner {
        require(rateUsdcPerEusd_ > 0, "ZERO");
        rateUsdcPerEusd = rateUsdcPerEusd_;
        emit RateSet(rateUsdcPerEusd_);
    }

    function fundUsdc(uint256 amt) external nonReentrant {
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        usdcLiquidity += amt;
        emit UsdcFunded(amt, usdcLiquidity);
    }

    /// @notice Open corridor + OpenMoney invoice (merchant must be listed).
    function openCorridor(
        bytes32 corridorId,
        bytes32 invoiceId,
        address merchant,
        address payer,
        address beneficiary,
        uint256 eusdAmount
    ) external onlyDesk {
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
        if (corridorId == bytes32(0) || invoiceId == bytes32(0) || eusdAmount == 0) revert Bad();
        if (txs[corridorId].status != 0) revert Bad();
        // Merchant must be OpenMoney-listed when OM is wired (desk creates invoice separately — OM onlyOwner/merchant).
        if (openMoney != address(0) && !IOpenMoney(openMoney).merchant(merchant)) revert Bad();

        uint256 usdcAmt = (eusdAmount * rateUsdcPerEusd) / 1e18;
        txs[corridorId] = CorridorTx({
            invoiceId: invoiceId,
            merchant: merchant,
            payer: payer,
            beneficiary: beneficiary,
            eusdAmount: eusdAmount,
            usdcAmount: usdcAmt,
            status: 1
        });
        emit CorridorOpened(corridorId, invoiceId, merchant, payer, eusdAmount);
    }

    /// @notice Payer pays eUSD into corridor escrow (or via OpenMoney then desk forwards).
    function captureEusd(bytes32 corridorId) external nonReentrant {
        CorridorTx storage t = txs[corridorId];
        if (t.status != 1) revert Status();
        if (msg.sender != t.payer && msg.sender != desk && msg.sender != owner) revert Auth();
        t.status = 2;
        eusd.safeTransferFrom(t.payer, address(this), t.eusdAmount);
        emit EusdCaptured(corridorId, t.eusdAmount);
    }

    /// @notice Desk settles USDC out to beneficiary — real buying-power leg.
    function settleUsdc(bytes32 corridorId) external nonReentrant onlyDesk {
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
        CorridorTx storage t = txs[corridorId];
        if (t.status != 2) revert Status();
        if (usdcLiquidity < t.usdcAmount) revert Liquidity();
        t.status = 3;
        usdcLiquidity -= t.usdcAmount;
        usdc.safeTransfer(t.beneficiary, t.usdcAmount);
        emit UsdcSettled(corridorId, t.beneficiary, t.usdcAmount);
    }

    /// @notice Sweep captured eUSD to desk/treasury after USDC settle.
    function sweepEusd(address to, uint256 amt) external onlyOwner {
        eusd.safeTransfer(to, amt);
    }
}
