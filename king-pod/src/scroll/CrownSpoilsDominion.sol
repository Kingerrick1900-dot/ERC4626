// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../core/Core.sol";

/// @notice Scroll dominion registry — spoils of war surface under Elepan rules.
/// @dev Records sovereign credit capacity and capture events. Does not touch Base.
contract CrownSpoilsDominion is Ownable {
    address public immutable king;
    address public immutable landing;
    address public gate;
    address public credit;
    address public completer;
    address public eusd;

    string public constant DOMAIN = "SCROLL_ELEPAN_DOMINION";
    uint256 public capacityUsdc6;
    uint256 public spoilsClaimedUsdc6;

    event Wired(address gate, address credit, address completer, address eusd);
    event CapacitySet(uint256 capacityUsdc6);
    event SpoilRecorded(address indexed from, uint256 amountUsdc6, bytes32 indexed tag);

    constructor(address king_, address landing_, address owner_) Ownable(owner_) {
        require(king_ != address(0) && landing_ != address(0), "ADDR");
        king = king_;
        landing = landing_;
    }

    function wire(address gate_, address credit_, address completer_, address eusd_) external onlyOwner {
        gate = gate_;
        credit = credit_;
        completer = completer_;
        eusd = eusd_;
        emit Wired(gate_, credit_, completer_, eusd_);
    }

    function setCapacity(uint256 capacityUsdc6_) external onlyOwner {
        capacityUsdc6 = capacityUsdc6_;
        emit CapacitySet(capacityUsdc6_);
    }

    /// @notice Book a spoil event (desk fill / completer draw) for dominion accounting.
    function recordSpoil(uint256 amountUsdc6, bytes32 tag) external onlyOwner {
        spoilsClaimedUsdc6 += amountUsdc6;
        emit SpoilRecorded(msg.sender, amountUsdc6, tag);
    }

    function status()
        external
        view
        returns (address king_, address landing_, uint256 capacity, uint256 claimed, address credit_)
    {
        return (king, landing, capacityUsdc6, spoilsClaimedUsdc6, credit);
    }
}
