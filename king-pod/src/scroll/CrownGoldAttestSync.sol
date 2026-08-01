// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Syncs Elepan sovereign gate capacity from kXAU (free + CDP coll) @ kingdom oracle.
/// @dev Completer maxAsk then tracks gold-backed attestation. Scroll-only; Base untouched.
interface IGateA {
    function minThreshold() external view returns (uint256);
}

interface IGoldA {
    function balanceOf(address) external view returns (uint256);
}

interface IOracleA {
    function price() external view returns (uint256);
}

interface ICdpA {
    function coll() external view returns (uint256);
}

contract CrownGoldAttestSync {
    address public immutable king;
    IGateA public immutable gate;
    IGoldA public immutable gold;
    IOracleA public immutable oracle;
    ICdpA public immutable cdp;

    event Synced(address indexed subject, uint256 capacityUsdc6, uint256 goldUnits8);

    error NotKing();
    error BelowMin();

    constructor(address king_, address gate_, address gold_, address oracle_, address cdp_) {
        require(king_ != address(0) && gate_ != address(0), "ADDR");
        require(gold_ != address(0) && oracle_ != address(0) && cdp_ != address(0), "ADDR");
        king = king_;
        gate = IGateA(gate_);
        gold = IGoldA(gold_);
        oracle = IOracleA(oracle_);
        cdp = ICdpA(cdp_);
    }

    /// @notice USDC-6dp notional = (free kXAU + CDP coll) * oracle.price / 1e36
    function capacityUsdc6() public view returns (uint256) {
        uint256 units = gold.balanceOf(king) + cdp.coll();
        return (units * oracle.price()) / 1e36;
    }

    function goldUnits8() public view returns (uint256) {
        return gold.balanceOf(king) + cdp.coll();
    }

    /// @notice King snapshots gold capacity; caller attests on gate in same tx (gate onlyOwner).
    function snapshot() external returns (uint256 cap) {
        if (msg.sender != king) revert NotKing();
        cap = capacityUsdc6();
        if (cap < gate.minThreshold()) revert BelowMin();
        emit Synced(king, cap, goldUnits8());
    }
}
