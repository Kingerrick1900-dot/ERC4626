// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Kingdom yield sink — real USDC only. Engines push; King/Landing pull.
contract CrownColdBuffer is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    address public landing;
    address public king;

    mapping(address => bool) public pushers;

    uint256 public totalReceived;
    uint256 public totalWithdrawn;

    event PusherSet(address indexed pusher, bool ok);
    event LandingSet(address landing);
    event Received(address indexed from, uint256 amt, bytes32 indexed tag);
    event Withdrawn(address indexed to, uint256 amt);

    error Bad();
    error NotPusher();

    constructor(address usdc_, address king_, address landing_, address owner_) Ownable(owner_) {
        if (usdc_ == address(0) || king_ == address(0) || landing_ == address(0)) revert Bad();
        usdc = IERC20(usdc_);
        king = king_;
        landing = landing_;
        pushers[owner_] = true;
    }

    function setPusher(address p, bool ok) external onlyOwner {
        pushers[p] = ok;
        emit PusherSet(p, ok);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert Bad();
        landing = landing_;
        emit LandingSet(landing_);
    }

    /// @notice Engines call after harvest. Tag distinguishes RWA / OCEAN / FLASH.
    function receiveYield(uint256 amt, bytes32 tag) external nonReentrant {
        if (!pushers[msg.sender]) revert NotPusher();
        if (amt == 0) revert Bad();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        totalReceived += amt;
        emit Received(msg.sender, amt, tag);
    }

    function withdrawToLanding(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert Bad();
        totalWithdrawn += amt;
        usdc.safeTransfer(landing, amt);
        emit Withdrawn(landing, amt);
    }

    function withdrawToKing(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert Bad();
        totalWithdrawn += amt;
        usdc.safeTransfer(king, amt);
        emit Withdrawn(king, amt);
    }

    function balance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}
