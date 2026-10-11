// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IColdBufferFundS {
    function fund(uint256 amount) external;
}

/// @title CrownSpoilsOfWar — end-state spoil accrual
/// @notice External USDC spoils only. Split: 30% ColdBuffer · 50% Ocean external · 20% HOT.
/// @dev Mirror eUSD mint is not a spoil. King may retarget Ocean sink; cold floor cannot drop below 3000.
contract CrownSpoilsOfWar is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IColdBufferFundS public immutable cold;
    address public immutable hot;

    address public oceanExternal; // DeepPull / Ocean USDC leg sink
    uint256 public coldBps = 3000; // 30% — law floor
    uint256 public oceanBps = 5000; // 50%
    // hotBps = 10000 - cold - ocean → 20% default

    uint256 public totalSpoils;
    uint256 public totalCold;
    uint256 public totalOcean;
    uint256 public totalHot;

    event OceanSet(address indexed sink);
    event BpsSet(uint256 coldBps, uint256 oceanBps);
    event Spoil(
        bytes32 indexed campaign, address indexed from, uint256 amount, uint256 toCold, uint256 toOcean, uint256 toHot
    );

    error BadBps();
    error BadSink();
    error Zero();

    constructor(address usdc_, address cold_, address hot_, address ocean_, address owner_) Ownable(owner_) {
        require(usdc_ != address(0) && cold_ != address(0) && hot_ != address(0), "ZERO");
        usdc = IERC20(usdc_);
        cold = IColdBufferFundS(cold_);
        hot = hot_;
        oceanExternal = ocean_;
    }

    function setOceanExternal(address sink) external onlyOwner {
        if (sink == address(0)) revert BadSink();
        oceanExternal = sink;
        emit OceanSet(sink);
    }

    /// @notice Retarget split. coldBps cannot fall below 3000.
    function setBps(uint256 coldBps_, uint256 oceanBps_) external onlyOwner {
        if (coldBps_ < 3000) revert BadBps();
        if (coldBps_ + oceanBps_ > 10_000) revert BadBps();
        coldBps = coldBps_;
        oceanBps = oceanBps_;
        emit BpsSet(coldBps_, oceanBps_);
    }

    /// @notice Pull `amount` USDC (0 = full balance of msg.sender after transferFrom intent).
    /// @dev Caller must approve this contract. `campaign` tags the spoil source (A/B/TWAMM/Fire/…).
    function takeSpoil(uint256 amount, bytes32 campaign) external nonReentrant returns (uint256 taken) {
        address ocean = oceanExternal;
        if (ocean == address(0)) revert BadSink();

        uint256 bal = usdc.balanceOf(msg.sender);
        if (amount == 0) amount = bal;
        if (amount == 0 || amount > bal) revert Zero();

        usdc.safeTransferFrom(msg.sender, address(this), amount);
        taken = amount;

        uint256 toCold = (amount * coldBps) / 10_000;
        uint256 toOcean = (amount * oceanBps) / 10_000;
        uint256 toHot = amount - toCold - toOcean;

        if (toCold > 0) {
            usdc.safeApprove(address(cold), 0);
            usdc.safeApprove(address(cold), toCold);
            cold.fund(toCold);
        }
        if (toOcean > 0) usdc.safeTransfer(ocean, toOcean);
        if (toHot > 0) usdc.safeTransfer(hot, toHot);

        totalSpoils += amount;
        totalCold += toCold;
        totalOcean += toOcean;
        totalHot += toHot;
        emit Spoil(campaign, msg.sender, amount, toCold, toOcean, toHot);
    }

    function book()
        external
        view
        returns (uint256 spoils, uint256 coldAmt, uint256 oceanAmt, uint256 hotAmt, uint256 cBps, uint256 oBps)
    {
        return (totalSpoils, totalCold, totalOcean, totalHot, coldBps, oceanBps);
    }
}
