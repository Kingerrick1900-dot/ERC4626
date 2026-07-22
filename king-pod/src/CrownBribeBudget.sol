// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IAeroVoterB {
    function gauges(address pool) external view returns (address);
    function gaugeToBribe(address gauge) external view returns (address);
    function createGauge(address pool, address factory) external returns (address);
    function isWhitelistedToken(address token) external view returns (bool);
}

interface IAeroBribeB {
    function notifyRewardAmount(address token, uint256 amount) external;
}

/// @notice ENGINEER 2 — Bribe magnet. Stock RSS → Aero gauge bribe OR direct LP rebate.
/// @dev Aero may block createGauge / RSS whitelist. Direct rebate still creates the APR opportunity.
contract CrownBribeBudget is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    address public immutable king;

    address public voter = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;
    address public aeroFactory = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public pool;
    address public gauge;
    address public bribe;

    uint256 public budgetRss;
    uint256 public bribedRss;
    uint256 public rebatedRss;

    event PoolSet(address pool, address gauge, address bribe);
    event Stocked(uint256 rssAmt);
    event Bribed(address bribe, uint256 rssAmt);
    event DirectRebate(address indexed lp, uint256 rssAmt);
    event Unstocked(address to, uint256 rssAmt);

    error BadAmt();
    error NoGauge();
    error NotWhitelisted();

    constructor(address rss_, address king_, address owner_) Ownable(owner_) {
        rss = IERC20(rss_);
        king = king_;
    }

    function setPool(address pool_) external onlyOwner {
        pool = pool_;
        address g = IAeroVoterB(voter).gauges(pool_);
        gauge = g;
        bribe = g == address(0) ? address(0) : IAeroVoterB(voter).gaugeToBribe(g);
        emit PoolSet(pool_, gauge, bribe);
    }

    /// @notice Attempt Aero createGauge (reverts if factory path not approved — shelf call).
    function tryCreateGauge() external onlyOwner returns (address g) {
        if (pool == address(0)) revert BadAmt();
        g = IAeroVoterB(voter).createGauge(pool, aeroFactory);
        gauge = g;
        bribe = IAeroVoterB(voter).gaugeToBribe(g);
        emit PoolSet(pool, gauge, bribe);
    }

    function stock(uint256 rssAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        budgetRss += rssAmt;
        emit Stocked(rssAmt);
    }

    /// @notice Push RSS into Aero bribe contract for the pool gauge.
    function bribeGauge(uint256 rssAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0 || rssAmt > budgetRss) revert BadAmt();
        if (bribe == address(0)) revert NoGauge();
        if (!IAeroVoterB(voter).isWhitelistedToken(address(rss))) revert NotWhitelisted();
        budgetRss -= rssAmt;
        bribedRss += rssAmt;
        rss.safeApprove(bribe, rssAmt);
        IAeroBribeB(bribe).notifyRewardAmount(address(rss), rssAmt);
        emit Bribed(bribe, rssAmt);
    }

    /// @notice CREATE PATH King controls — pay RSS rebate direct to an LP (no Aero whitelist).
    function directRebate(address lp, uint256 rssAmt) external onlyOwner nonReentrant {
        if (lp == address(0) || rssAmt == 0 || rssAmt > budgetRss) revert BadAmt();
        budgetRss -= rssAmt;
        rebatedRss += rssAmt;
        rss.safeTransfer(lp, rssAmt);
        emit DirectRebate(lp, rssAmt);
    }

    function unstock(uint256 rssAmt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = king;
        if (rssAmt == 0 || rssAmt > budgetRss) revert BadAmt();
        budgetRss -= rssAmt;
        rss.safeTransfer(to, rssAmt);
        emit Unstocked(to, rssAmt);
    }
}
