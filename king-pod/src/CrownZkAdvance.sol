// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGate {
    function isProven(address subject) external view returns (bool);
    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

/// @notice PRIMARY fill door — USDC advance ONLY while King ZK isProven.
/// @dev Counterparty verifies gate, then advance(): USDC → Landing, kUSD → buyer @ 1:1.
contract CrownZkAdvance is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable kusd;
    IZkGate public immutable gate;
    address public immutable king;
    address public landing;

    uint256 public kusdStock;
    uint256 public raisedUsdc;

    event LandingSet(address landing);
    event StockedKusd(uint256 amt);
    event Advanced(address indexed buyer, uint256 usdcIn, uint256 kusdOut, address landing);

    error BadAmt();
    error KingNotProven();
    error Empty();

    constructor(
        address usdc_,
        address kusd_,
        address gate_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        usdc = IERC20(usdc_);
        kusd = IERC20(kusd_);
        gate = IZkGate(gate_);
        king = king_;
        landing = landing_;
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function stockKusd(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        kusd.safeTransferFrom(msg.sender, address(this), amt);
        kusdStock += amt;
        emit StockedKusd(amt);
    }

    function unstockKusd(uint256 amt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = king;
        if (amt == 0 || amt > kusdStock) revert BadAmt();
        kusdStock -= amt;
        kusd.safeTransfer(to, amt);
    }

    /// @notice Force-fill: requires King ZK live. USDC → Landing. kUSD → buyer.
    function advance(uint256 usdcAmt) external nonReentrant {
        if (usdcAmt == 0) revert BadAmt();
        if (!gate.isProven(king)) revert KingNotProven();
        if (usdcAmt > kusdStock) revert Empty();

        usdc.safeTransferFrom(msg.sender, landing, usdcAmt);
        kusdStock -= usdcAmt;
        raisedUsdc += usdcAmt;
        kusd.safeTransfer(msg.sender, usdcAmt);

        emit Advanced(msg.sender, usdcAmt, usdcAmt, landing);
    }

    function quote() external view returns (bool kingProven, uint256 kusdAvailable, uint256 threshold) {
        kingProven = gate.isProven(king);
        kusdAvailable = kusdStock;
        (threshold,,) = gate.attestations(king);
    }
}
