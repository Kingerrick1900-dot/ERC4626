// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Fixes the empty-pool block: permissioned systems seed REAL USDC inventory;
///         King sells RSS into that inventory and USDC hits treasury the same tx.
/// @dev Does NOT route through sUSDC paper shares (those steal new deposits when vault idle=0).
///      Seeders are systems-only (allowlist). Public buyers are off.
contract KingSeedDesk is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    address public treasury;

    /// @notice USDC (6 decimals) paid to King per 1e18 RSS. Default $0.05 = 50_000.
    uint256 public priceUsdcPerRss;
    bool public paused;

    mapping(address => bool) public isSeeder;
    mapping(address => bool) public isFiller; // CrownEliteClose / bundler adapters
    mapping(address => uint256) public seededUsdc; // USDC each system has seeded
    mapping(address => uint256) public claimedRss; // RSS already claimed by seeder

    uint256 public totalSeededUsdc;
    uint256 public totalRssSold;

    event SeederSet(address indexed who, bool allowed);
    event FillerSet(address indexed who, bool allowed);
    event Seeded(address indexed seeder, uint256 usdcIn, uint256 inventory);
    event KingSold(uint256 rssIn, uint256 usdcOut, address indexed treasury);
    event SeederClaimed(address indexed seeder, uint256 rssOut);
    event PriceSet(uint256 priceUsdcPerRss);
    event TreasurySet(address treasury);
    event Paused(bool paused);

    error PausedError();
    error NotSeeder();
    error NotFiller();
    error BadPrice();
    error Zero();
    error Inventory();
    error Claim();

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    constructor(address rss_, address usdc_, address treasury_, uint256 price_, address owner_) Ownable(owner_) {
        require(rss_ != address(0) && usdc_ != address(0) && treasury_ != address(0), "ZERO");
        if (price_ == 0) revert BadPrice();
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        treasury = treasury_;
        priceUsdcPerRss = price_;
        // Owner/King can seed too (bootstrap allies / protocol rails).
        isSeeder[owner_] = true;
        isSeeder[treasury_] = true;
    }

    function inventoryUsdc() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /// @notice Max RSS King can sell against current inventory at current price.
    function maxRssSellable() public view returns (uint256) {
        uint256 inv = inventoryUsdc();
        if (priceUsdcPerRss == 0) return 0;
        return (inv * 1e18) / priceUsdcPerRss;
    }

    function setSeeder(address who, bool allowed) external onlyOwner {
        require(who != address(0), "ZERO");
        isSeeder[who] = allowed;
        emit SeederSet(who, allowed);
    }

    function setFiller(address who, bool allowed) external onlyOwner {
        require(who != address(0), "ZERO");
        isFiller[who] = allowed;
        emit FillerSet(who, allowed);
    }

    function setPrice(uint256 price_) external onlyOwner {
        if (price_ == 0) revert BadPrice();
        priceUsdcPerRss = price_;
        emit PriceSet(price_);
    }

    function setTreasury(address t) external onlyOwner {
        require(t != address(0), "ZERO");
        treasury = t;
        emit TreasurySet(t);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    /// @notice Systems/allies deposit REAL USDC seed. This is the pool inventory.
    function seed(uint256 usdcAmount) external nonReentrant whenNotPaused {
        if (!isSeeder[msg.sender]) revert NotSeeder();
        if (usdcAmount == 0) revert Zero();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        seededUsdc[msg.sender] += usdcAmount;
        totalSeededUsdc += usdcAmount;
        emit Seeded(msg.sender, usdcAmount, inventoryUsdc());
    }

    /// @notice King sells RSS into seeded inventory → hard USDC to treasury.
    /// @dev Credits all allowlisted seeders pro-rata claimable RSS for their share of inventory paid out.
    function kingSellRss(uint256 rssAmount, uint256 minUsdcOut) external onlyOwner nonReentrant whenNotPaused {
        _sellRss(msg.sender, rssAmount, minUsdcOut, treasury);
    }

    /// @notice CrownSeedFill rail for elite close: sell RSS, USDC to a named receiver (repay adapter).
    /// @dev Same inventory math as kingSellRss; receiver is the Morpho repay leg, not always treasury.
    function fillSellRss(uint256 rssAmount, uint256 minUsdcOut, address usdcReceiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 usdcOut)
    {
        if (!isFiller[msg.sender] && msg.sender != owner) revert NotFiller();
        if (usdcReceiver == address(0)) revert Zero();
        usdcOut = _sellRss(msg.sender, rssAmount, minUsdcOut, usdcReceiver);
    }

    function _sellRss(address from, uint256 rssAmount, uint256 minUsdcOut, address usdcReceiver)
        private
        returns (uint256 usdcOut)
    {
        if (rssAmount == 0) revert Zero();
        usdcOut = (rssAmount * priceUsdcPerRss) / 1e18;
        if (usdcOut == 0) revert Zero();
        if (usdcOut < minUsdcOut) revert Inventory();
        if (usdcOut > inventoryUsdc()) revert Inventory();

        rss.safeTransferFrom(from, address(this), rssAmount);
        usdc.safeTransfer(usdcReceiver, usdcOut);
        totalRssSold += rssAmount;
        emit KingSold(rssAmount, usdcOut, usdcReceiver);
    }

    /// @notice Seeder claims RSS earned from King sells, pro-rata of their seed.
    function claimRss() external nonReentrant {
        uint256 seeded = seededUsdc[msg.sender];
        if (seeded == 0 || totalSeededUsdc == 0) revert Claim();
        uint256 entitled = (totalRssSold * seeded) / totalSeededUsdc;
        uint256 already = claimedRss[msg.sender];
        if (entitled <= already) revert Claim();
        uint256 due = entitled - already;
        uint256 bal = rss.balanceOf(address(this));
        if (due > bal) due = bal;
        if (due == 0) revert Claim();
        claimedRss[msg.sender] = already + due;
        rss.safeTransfer(msg.sender, due);
        emit SeederClaimed(msg.sender, due);
    }

    /// @notice Owner rescue: pull leftover RSS/USDC (emergencies).
    function rescue(address token, uint256 amt, address to) external onlyOwner {
        require(to != address(0), "ZERO");
        IERC20(token).safeTransfer(to, amt);
    }
}
