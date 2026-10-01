// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable} from "./lib/Core.sol";

/// @notice Generic eUSD park sleeve (Pendle PT pending / Aave-class pending).
contract CrownEusdSleeve is Ownable {
    using SafeTransfer for IERC20;
    IERC20 public immutable eusd;
    string public label;

    constructor(address eusd_, address owner_, string memory label_) Ownable(owner_) {
        eusd = IERC20(eusd_);
        label = label_;
    }

    function pull(address to, uint256 amt) external onlyOwner {
        eusd.safeTransfer(to, amt == 0 ? eusd.balanceOf(address(this)) : amt);
    }

    function bal() external view returns (uint256) {
        return eusd.balanceOf(address(this));
    }
}
