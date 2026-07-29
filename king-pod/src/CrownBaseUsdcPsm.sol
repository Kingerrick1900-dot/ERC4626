// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IKingdomEusd {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
    function isMinter(address) external view returns (bool);
    function transferFrom(address from, address to, uint256 amt) external returns (bool);
}

/// @notice Base Maker-style PSM — 1:1 eUSD ↔ USDC mint/redeem.
/// @dev Mint leg: USDC in → mint eUSD (peg ceiling). Redeem leg: burn eUSD → USDC out (peg floor).
///      PSM must be eUSD minter. Redeem depth = USDC reserves (seed before scaling CDP debt).
contract CrownBaseUsdcPsm is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant EUSD_PER_USDC = 1e12; // 18dp / 6dp

    IKingdomEusd public immutable eusd;
    IERC20 public immutable usdc;
    address public immutable landing;

    uint16 public feeBps; // both legs → Landing (USDC)
    uint256 public dailyCapUsdc; // 0 = uncapped
    uint256 public dayStart;
    uint256 public dayUsedUsdc;
    bool public paused;

    event Minted(address indexed user, uint256 usdcIn, uint256 eusdOut, uint256 feeUsdc);
    event Redeemed(address indexed user, uint256 eusdIn, uint256 usdcOut, uint256 feeUsdc);
    event UsdcSeeded(uint256 amount);
    event Swept(address indexed token, uint256 amount, address to);
    event FeeBpsSet(uint16 feeBps);
    event DailyCapSet(uint256 capUsdc);
    event PauseSet(bool paused);

    error Paused();
    error Cap();
    error Dust();
    error Dry();
    error NotMinter();

    constructor(address owner_, address landing_, address eusd_, address usdc_, uint16 feeBps_) Ownable(owner_) {
        require(owner_ != address(0) && landing_ != address(0), "ADDR");
        require(eusd_ != address(0) && usdc_ != address(0), "TOK");
        landing = landing_;
        eusd = IKingdomEusd(eusd_);
        usdc = IERC20(usdc_);
        feeBps = feeBps_;
        dayStart = block.timestamp;
    }

    modifier live() {
        if (paused) revert Paused();
        _;
    }

    /// @notice USDC → eUSD at $1. Mints eUSD; grows redeem reserve.
    function mint(uint256 usdcIn, address receiver) external nonReentrant live returns (uint256 eusdOut) {
        if (usdcIn == 0) revert Dust();
        if (receiver == address(0)) receiver = msg.sender;
        if (!eusd.isMinter(address(this))) revert NotMinter();

        _bumpDay(usdcIn);
        uint256 fee = (usdcIn * feeBps) / BPS;
        uint256 usdcNet = usdcIn - fee;
        eusdOut = usdcNet * EUSD_PER_USDC;
        if (eusdOut == 0) revert Dust();

        usdc.safeTransferFrom(msg.sender, address(this), usdcIn);
        if (fee > 0) usdc.safeTransfer(landing, fee);
        eusd.mint(receiver, eusdOut);
        emit Minted(msg.sender, usdcIn, eusdOut, fee);
    }

    /// @notice eUSD → USDC at $1. Burns eUSD; pays from USDC reserve.
    function redeem(uint256 eusdIn, address receiver) external nonReentrant live returns (uint256 usdcOut) {
        if (eusdIn < EUSD_PER_USDC) revert Dust();
        if (receiver == address(0)) receiver = msg.sender;
        if (!eusd.isMinter(address(this))) revert NotMinter();

        uint256 usdcGross = eusdIn / EUSD_PER_USDC;
        _bumpDay(usdcGross);

        uint256 fee = (usdcGross * feeBps) / BPS;
        usdcOut = usdcGross - fee;
        if (usdcOut == 0) revert Dust();
        if (usdc.balanceOf(address(this)) < usdcGross) revert Dry();

        eusd.transferFrom(msg.sender, address(this), eusdIn);
        eusd.burn(address(this), eusdIn);
        if (fee > 0) usdc.safeTransfer(landing, fee);
        usdc.safeTransfer(receiver, usdcOut);
        emit Redeemed(msg.sender, eusdIn, usdcOut, fee);
    }

    /// @dev Explicit amount only — never drain full wallet.
    function seedUsdc(uint256 amount) external nonReentrant {
        require(msg.sender == owner, "KING");
        require(amount > 0, "AMT");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit UsdcSeeded(amount);
    }

    function sweep(address token, uint256 amount, address to) external onlyOwner {
        if (to == address(0)) to = landing;
        if (amount == 0) amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, amount);
        emit Swept(token, amount, to);
    }

    function setFeeBps(uint16 feeBps_) external onlyOwner {
        require(feeBps_ <= 500, "FEE");
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

    function quoteMint(uint256 usdcIn) external view returns (uint256 eusdOut, uint256 feeUsdc) {
        feeUsdc = (usdcIn * feeBps) / BPS;
        eusdOut = (usdcIn - feeUsdc) * EUSD_PER_USDC;
    }

    function quoteRedeem(uint256 eusdIn) external view returns (uint256 usdcOut, uint256 feeUsdc) {
        uint256 usdcGross = eusdIn / EUSD_PER_USDC;
        feeUsdc = (usdcGross * feeBps) / BPS;
        usdcOut = usdcGross - feeUsdc;
    }

    function usdcReserve() external view returns (uint256) {
        return usdc.balanceOf(address(this));
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
