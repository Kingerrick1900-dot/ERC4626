// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IERC20Cold {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Sovereign KRT cold vault — only king (Safe) can release. No timelock.
contract CrownSovereignColdKrt is Ownable {
    IERC20Cold public immutable krt;
    address public immutable king;

    event Released(address indexed to, uint256 amount);

    error Auth();

    constructor(address krt_, address king_, address owner_) Ownable(owner_) {
        require(krt_ != address(0) && king_ != address(0), "ZERO");
        krt = IERC20Cold(krt_);
        king = king_;
    }

    function release(address to, uint256 amount) external {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        require(to != address(0), "ZERO");
        require(krt.transfer(to, amount), "XFER");
        emit Released(to, amount);
    }

    function balance() external view returns (uint256) {
        return krt.balanceOf(address(this));
    }
}
