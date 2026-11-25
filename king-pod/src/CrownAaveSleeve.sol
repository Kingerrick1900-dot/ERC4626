// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

/// @title CrownAaveSleeve
/// @notice Real Aave V3 Base USDC sleeve for native loop hard-asset yield.
contract CrownAaveSleeve is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IAavePool public immutable pool;
    address public immutable hot;

    event Supplied(uint256 amt);
    event Withdrawn(uint256 amt, address to);

    error Bad();

    constructor(address usdc_, address pool_, address hot_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        pool = IAavePool(pool_);
        hot = hot_;
    }

    function supply(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert Bad();
        usdc.safeApprove(address(pool), amt);
        pool.supply(address(usdc), amt, address(this), 0);
        emit Supplied(amt);
    }

    function withdrawToHot(uint256 amt) external onlyOwner nonReentrant returns (uint256) {
        uint256 out = pool.withdraw(address(usdc), amt == 0 ? type(uint256).max : amt, hot);
        emit Withdrawn(out, hot);
        return out;
    }

    function fundFrom(address from, uint256 amt) external onlyOwner {
        usdc.safeTransferFrom(from, address(this), amt);
    }
}
