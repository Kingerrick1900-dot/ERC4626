// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkGateL {
    function isProven(address subject) external view returns (bool);
}

interface IBordersL {
    function bordersSecure() external view returns (bool);
}

/// @notice Build 1 — SovereignRail LLTV lever. Default 55%. King trigger, no floor/ceiling lock.
contract SovereignRailLLTV55 is Ownable {
    IZkGateL public immutable zkGate;
    IBordersL public immutable attest;
    address public immutable king;

    uint256 public constant DEFAULT_LLTV = 550000000000000000; // 55%
    uint256 public lltv;

    event LltvSet(uint256 lltv, address indexed signer);

    error Auth();
    error Zero();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(address zkGate_, address attest_, address king_, address owner_) Ownable(owner_) {
        require(zkGate_ != address(0) && attest_ != address(0) && king_ != address(0), "ZERO");
        zkGate = IZkGateL(zkGate_);
        attest = IBordersL(attest_);
        king = king_;
        lltv = DEFAULT_LLTV;
    }

    /// @notice King-only LLTV trigger. Safe-owned after crown. No floor/ceiling.
    function setLLTV(uint256 newLltv) external whenZk {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        if (newLltv == 0) revert Zero();
        lltv = newLltv;
        emit LltvSet(newLltv, msg.sender);
    }
}
