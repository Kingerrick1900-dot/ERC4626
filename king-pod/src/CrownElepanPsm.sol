// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Kingdom PSM — eUSD ↔ USDC at soft $1. No external curator.
/// @dev eUSD is 18dp, USDC is 6dp. CDP alone mints/burns eUSD; this PSM holds inventory + USDC reserve.
///      buyUsdc:  eUSD in  → USDC out (clears kingdom credit to dollars when reserve exists)
///      sellUsdc: USDC in → eUSD out (grows USDC reserve; pays eUSD from inventory)
contract CrownElepanPsm is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant EUSD_PER_USDC = 1e12; // 1e18 / 1e6

    IERC20 public immutable eusd;
    IERC20 public immutable usdc;
    address public immutable king;
    address public immutable landing;

    uint16 public feeBps; // fee on both legs → Landing
    uint256 public dailyCapUsdc; // 0 = uncapped
    uint256 public dayStart;
    uint256 public dayUsedUsdc;
    bool public paused;

    event BoughtUsdc(address indexed user, uint256 eusdIn, uint256 usdcOut, uint256 feeUsdc);
    event SoldUsdc(address indexed user, uint256 usdcIn, uint256 eusdOut, uint256 feeUsdc);
    event Seeded(address indexed token, uint256 amount);
    event Swept(address indexed token, uint256 amount, address to);
    event FeeBpsSet(uint16 feeBps);
    event DailyCapSet(uint256 capUsdc);
    event PauseSet(bool paused);

    error Paused();
    error Cap();
    error Dust();
    error Empty();

    constructor(address king_, address landing_, address eusd_, address usdc_, uint16 feeBps_) Ownable(king_) {
        require(king_ != address(0) && landing_ != address(0), "ADDR");
        king = king_;
        landing = landing_;
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
        feeBps = feeBps_;
        dayStart = block.timestamp;
    }

    modifier live() {
        if (paused) revert Paused();
        _;
    }

    /// @notice eUSD → USDC. Burns nothing; sterilizes eUSD in the PSM.
    function buyUsdc(uint256 eusdIn, address receiver) external nonReentrant live returns (uint256 usdcOut) {
        if (eusdIn < EUSD_PER_USDC) revert Dust();
        if (receiver == address(0)) receiver = msg.sender;

        uint256 usdcGross = eusdIn / EUSD_PER_USDC;
        _bumpDay(usdcGross);

        uint256 fee = (usdcGross * feeBps) / BPS;
        usdcOut = usdcGross - fee;
        if (usdcOut == 0) revert Dust();
        if (usdc.balanceOf(address(this)) < usdcGross) revert Empty();

        eusd.safeTransferFrom(msg.sender, address(this), eusdIn);
        if (fee > 0) usdc.safeTransfer(landing, fee);
        usdc.safeTransfer(receiver, usdcOut);
        emit BoughtUsdc(msg.sender, eusdIn, usdcOut, fee);
    }

    /// @notice USDC → eUSD from inventory. Grows dollar reserve.
    function sellUsdc(uint256 usdcIn, address receiver) external nonReentrant live returns (uint256 eusdOut) {
        if (usdcIn == 0) revert Dust();
        if (receiver == address(0)) receiver = msg.sender;

        _bumpDay(usdcIn);
        uint256 fee = (usdcIn * feeBps) / BPS;
        uint256 usdcNet = usdcIn - fee;
        eusdOut = usdcNet * EUSD_PER_USDC;
        if (eusdOut == 0) revert Dust();
        if (eusd.balanceOf(address(this)) < eusdOut) revert Empty();

        usdc.safeTransferFrom(msg.sender, address(this), usdcIn);
        if (fee > 0) usdc.safeTransfer(landing, fee);
        eusd.safeTransfer(receiver, eusdOut);
        emit SoldUsdc(msg.sender, usdcIn, eusdOut, fee);
    }

    /// @dev Explicit `amount` only — never drain full wallet (keep gas / ops float).
    function seedUsdc(uint256 amount) external nonReentrant {
        require(msg.sender == king || msg.sender == owner, "KING");
        require(amount > 0, "AMT");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit Seeded(address(usdc), amount);
    }

    /// @dev Explicit `amount` only — never drain full wallet.
    function seedEusd(uint256 amount) external nonReentrant {
        require(msg.sender == king || msg.sender == owner, "KING");
        require(amount > 0, "AMT");
        eusd.safeTransferFrom(msg.sender, address(this), amount);
        emit Seeded(address(eusd), amount);
    }

    function sweep(address token, uint256 amount, address to) external onlyOwner {
        if (to == address(0)) to = landing;
        if (amount == 0) amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, amount);
        emit Swept(token, amount, to);
    }

    function setFeeBps(uint16 feeBps_) external onlyOwner {
        require(feeBps_ <= 500, "FEE"); // max 5%
        feeBps = feeBps_;
        emit FeeBpsSet(feeBps_);
    }

    function setDailyCapUsdc(uint256 cap) external onlyOwner {
        dailyCapUsdc = cap;
        emit DailyCapSet(cap);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit PauseSet(p);
    }

    function quoteBuyUsdc(uint256 eusdIn) external view returns (uint256 usdcOut, uint256 feeUsdc) {
        uint256 usdcGross = eusdIn / EUSD_PER_USDC;
        feeUsdc = (usdcGross * feeBps) / BPS;
        usdcOut = usdcGross - feeUsdc;
    }

    function quoteSellUsdc(uint256 usdcIn) external view returns (uint256 eusdOut, uint256 feeUsdc) {
        feeUsdc = (usdcIn * feeBps) / BPS;
        eusdOut = (usdcIn - feeUsdc) * EUSD_PER_USDC;
    }

    function reserves() external view returns (uint256 usdcBal, uint256 eusdBal) {
        usdcBal = usdc.balanceOf(address(this));
        eusdBal = eusd.balanceOf(address(this));
    }

    function _bumpDay(uint256 usdcAmt) internal {
        if (block.timestamp >= dayStart + 1 days) {
            dayStart = block.timestamp;
            dayUsedUsdc = 0;
        }
        dayUsedUsdc += usdcAmt;
        if (dailyCapUsdc != 0 && dayUsedUsdc > dailyCapUsdc) revert Cap();
    }
}
