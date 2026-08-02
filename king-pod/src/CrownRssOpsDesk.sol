// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Kingdom Ops Desk — protocol-grade RSS → USDC raise (on-chain OTC).
/// @dev Same class of tool desks use: inventory, fixed ask, proceeds to treasury.
///      King stocks freed RSS. Counterparties buy with USDC. Proceeds → Landing.
///      Price: USDC (6dp) paid per 1e18 RSS. Oracle peg $1 = 1e6.
///      No depositor borrowing. No flash games. Legal asset sale.
contract CrownRssOpsDesk is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    address public immutable king;

    address public landing;
    uint256 public priceUsdcPerRss; // USDC raw per 1e18 RSS (1e6 = $1)
    uint256 public rssForSale; // RSS wei listed
    bool public live;

    uint256 public raisedUsdc;
    uint256 public soldRss;

    event DeskArmed(address landing, uint256 priceUsdcPerRss, uint256 rssForSale);
    event DeskPaused();
    event Bought(address buyer, uint256 rssOut, uint256 usdcIn, address landing);
    event Stocked(uint256 rssAdded, uint256 rssForSale);
    event Unstocked(uint256 rssOut, address to);

    error NotLive();
    error BadAmt();
    error BadPrice();
    error SoldOut();

    constructor(address rss_, address usdc_, address king_, address owner_) Ownable(owner_) {
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        king = king_;
        landing = king_;
        priceUsdcPerRss = 1e6; // $1 default (Morpho FixedOracle peg)
    }

    /// @notice Stock desk from king inventory (RSS already free on hot).
    function stock(uint256 rssAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        rssForSale += rssAmt;
        emit Stocked(rssAmt, rssForSale);
    }

    /// @notice Arm the desk: price + landing + go live.
    function arm(address landing_, uint256 priceUsdcPerRss_, bool live_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        if (priceUsdcPerRss_ == 0) revert BadPrice();
        landing = landing_;
        priceUsdcPerRss = priceUsdcPerRss_;
        live = live_;
        emit DeskArmed(landing_, priceUsdcPerRss_, rssForSale);
        if (!live_) emit DeskPaused();
    }

    function pause() external onlyOwner {
        live = false;
        emit DeskPaused();
    }

    /// @notice Buy RSS with USDC. USDC → Landing. RSS → buyer.
    /// @param rssAmt amount of RSS (1e18) to purchase
    function buy(uint256 rssAmt) external nonReentrant {
        if (!live) revert NotLive();
        if (rssAmt == 0) revert BadAmt();
        if (rssAmt > rssForSale) revert SoldOut();

        // usdcIn = rssAmt * price / 1e18
        uint256 usdcIn = (rssAmt * priceUsdcPerRss) / 1e18;
        if (usdcIn == 0) revert BadAmt();

        usdc.safeTransferFrom(msg.sender, landing, usdcIn);
        rssForSale -= rssAmt;
        soldRss += rssAmt;
        raisedUsdc += usdcIn;
        rss.safeTransfer(msg.sender, rssAmt);

        emit Bought(msg.sender, rssAmt, usdcIn, landing);
    }

    /// @notice Buy exact USDC spend (ops-sized fill helper).
    /// @param usdcAmt USDC raw to spend; returns RSS purchased
    function buyWithUsdc(uint256 usdcAmt) external nonReentrant returns (uint256 rssAmt) {
        if (!live) revert NotLive();
        if (usdcAmt == 0) revert BadAmt();
        // rssAmt = usdcAmt * 1e18 / price
        rssAmt = (usdcAmt * 1e18) / priceUsdcPerRss;
        if (rssAmt == 0) revert BadAmt();
        if (rssAmt > rssForSale) revert SoldOut();

        usdc.safeTransferFrom(msg.sender, landing, usdcAmt);
        rssForSale -= rssAmt;
        soldRss += rssAmt;
        raisedUsdc += usdcAmt;
        rss.safeTransfer(msg.sender, rssAmt);

        emit Bought(msg.sender, rssAmt, usdcAmt, landing);
    }

    /// @notice Pull unsold RSS back to king (or `to`).
    function unstock(uint256 rssAmt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = king;
        if (rssAmt == 0 || rssAmt > rssForSale) revert BadAmt();
        rssForSale -= rssAmt;
        rss.safeTransfer(to, rssAmt);
        emit Unstocked(rssAmt, to);
    }

    function quoteUsdc(uint256 rssAmt) external view returns (uint256) {
        return (rssAmt * priceUsdcPerRss) / 1e18;
    }

    function quoteRss(uint256 usdcAmt) external view returns (uint256) {
        return (usdcAmt * 1e18) / priceUsdcPerRss;
    }
}
