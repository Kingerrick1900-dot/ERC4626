// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable} from "./lib/Core.sol";
import {KingSusdc} from "./KingSusdc.sol";
import {KingMoneyMarket} from "./KingMoneyMarket.sol";

/// @notice Phase C helper: when idle USDC sits in sUSDC, King borrows against existing LP.
///         12% team cut routed to `team`, remainder to `king`.
contract KingPhaseCBorrow is Ownable {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    KingMoneyMarket public immutable market;
    address public king;
    address public team;
    uint256 public teamBps = 1200; // 12%
    uint256 public constant BPS = 10_000;

    event PhaseCExecuted(uint256 borrowed, uint256 toTeam, uint256 toKing);

    constructor(address usdc_, address market_, address king_, address team_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        market = KingMoneyMarket(market_);
        king = king_;
        team = team_;
    }

    function setTeam(address t) external onlyOwner {
        require(t != address(0), "ZERO");
        team = t;
    }

    function setTeamBps(uint256 bps) external onlyOwner {
        require(bps <= 2000, "BPS"); // hard cap 20%
        teamBps = bps;
    }

    /// @param amount USDC (6 decimals) to borrow. Must be ≤ idle vault USDC and ≤ maxBorrow(king).
    function execute(uint256 amount) external onlyOwner {
        require(amount > 0, "ZERO");
        uint256 maxB = market.maxBorrow(king);
        require(amount <= maxB, "CAP");
        market.borrowTo(king, amount, address(this));
        uint256 toTeam = (amount * teamBps) / BPS;
        uint256 toKing = amount - toTeam;
        if (toTeam > 0) usdc.safeTransfer(team, toTeam);
        usdc.safeTransfer(king, toKing);
        emit PhaseCExecuted(amount, toTeam, toKing);
    }
}
