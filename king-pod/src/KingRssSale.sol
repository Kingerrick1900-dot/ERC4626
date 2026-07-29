// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Crown RSS → USDC sale rail. King loads RSS; buyers pay USDC; proceeds hit treasury.
/// @dev No DEX dependency. Price is Crown-set (USDC units per 1 full RSS / 1e18 wei).
contract KingRssSale is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    address public treasury;

    /// @notice USDC (6 decimals) charged per 1e18 RSS. Default Crown: $0.05 = 50_000.
    uint256 public priceUsdcPerRss;
    bool public paused;

    event Loaded(uint256 rssAmount);
    event Bought(address indexed buyer, uint256 rssAmount, uint256 usdcPaid, address treasury);
    event PriceSet(uint256 priceUsdcPerRss);
    event TreasurySet(address treasury);
    event Paused(bool paused);

    error PausedError();
    error BadPrice();
    error Zero();
    error Stock();

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
    }

    function stock() public view returns (uint256) {
        return rss.balanceOf(address(this));
    }

    /// @notice Max USDC this desk can still raise at current price/stock.
    function raiseableUsdc() external view returns (uint256) {
        return (stock() * priceUsdcPerRss) / 1e18;
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

    /// @notice Pull RSS from King/owner inventory into the sale desk.
    function load(uint256 rssAmount) external onlyOwner {
        if (rssAmount == 0) revert Zero();
        rss.safeTransferFrom(msg.sender, address(this), rssAmount);
        emit Loaded(rssAmount);
    }

    /// @notice Buy `rssAmount` at Crown price. USDC goes to treasury; RSS to buyer.
    function buy(uint256 rssAmount) external nonReentrant whenNotPaused {
        if (rssAmount == 0) revert Zero();
        if (rssAmount > stock()) revert Stock();
        uint256 usdcPaid = (rssAmount * priceUsdcPerRss) / 1e18;
        if (usdcPaid == 0) revert Zero();
        usdc.safeTransferFrom(msg.sender, treasury, usdcPaid);
        rss.safeTransfer(msg.sender, rssAmount);
        emit Bought(msg.sender, rssAmount, usdcPaid, treasury);
    }

    /// @notice Spend exact USDC for RSS (floored by price). Dust USDC not pulled.
    function buyWithUsdc(uint256 usdcAmount) external nonReentrant whenNotPaused returns (uint256 rssOut) {
        if (usdcAmount == 0) revert Zero();
        rssOut = (usdcAmount * 1e18) / priceUsdcPerRss;
        if (rssOut == 0) revert Zero();
        if (rssOut > stock()) revert Stock();
        uint256 usdcPaid = (rssOut * priceUsdcPerRss) / 1e18;
        usdc.safeTransferFrom(msg.sender, treasury, usdcPaid);
        rss.safeTransfer(msg.sender, rssOut);
        emit Bought(msg.sender, rssOut, usdcPaid, treasury);
    }

    function withdrawRss(uint256 amount, address to) external onlyOwner {
        require(to != address(0), "ZERO");
        rss.safeTransfer(to, amount == 0 ? stock() : amount);
    }

    function rescue(address token, uint256 amt, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amt);
    }
}
