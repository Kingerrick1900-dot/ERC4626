// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice On-chain segregation map — breach in one rail must not silently equal all rails.
/// @dev Records role → address. Ownership of modules should move to these roles over time.
contract CrownRailShield is Ownable {
    enum Rail {
        OpsGas, // HOT / ops tip sink
        Curator, // yRSS owner/curator
        Landing, // payroll receive
        Ocean, // BAMM / LP
        Attest, // ZK attest owner
        Cold, // cold buffer
        Hunt // hunt router owner
    }

    mapping(Rail => address) public rail;
    mapping(Rail => address) public pendingRail;
    uint256 public constant ROTATE_DELAY = 0; // instant under freeze fire; raise later
    mapping(Rail => uint256) public pendingAt;

    event RailSet(Rail indexed r, address indexed addr);
    event RailProposed(Rail indexed r, address indexed addr, uint256 when);
    event Decree(string text);

    constructor(address owner_) Ownable(owner_) {
        // Genesis decree — King Errick the righteous
        emit Decree("With Christ all things are possible - borders ZK-set forever");
    }

    function setRail(Rail r, address addr) external onlyOwner {
        rail[r] = addr;
        emit RailSet(r, addr);
    }

    function proposeRail(Rail r, address addr) external onlyOwner {
        pendingRail[r] = addr;
        pendingAt[r] = block.timestamp + ROTATE_DELAY;
        emit RailProposed(r, addr, pendingAt[r]);
    }

    function acceptRail(Rail r) external onlyOwner {
        require(block.timestamp >= pendingAt[r], "DELAY");
        address addr = pendingRail[r];
        require(addr != address(0), "ZERO");
        rail[r] = addr;
        delete pendingRail[r];
        delete pendingAt[r];
        emit RailSet(r, addr);
    }

    function allRails()
        external
        view
        returns (address ops, address curator, address landing, address ocean, address attest, address cold, address hunt)
    {
        return (
            rail[Rail.OpsGas],
            rail[Rail.Curator],
            rail[Rail.Landing],
            rail[Rail.Ocean],
            rail[Rail.Attest],
            rail[Rail.Cold],
            rail[Rail.Hunt]
        );
    }
}
