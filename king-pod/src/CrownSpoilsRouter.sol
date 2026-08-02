// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable} from "./lib/Core.sol";

/// @notice Sweep spoils (USDC/RSS/ETH) to Landing treasury. King hot owner only.
contract CrownSpoilsRouter is Ownable {
    using SafeTransfer for IERC20;

    address public landing;

    event LandingSet(address landing);
    event Swept(address indexed token, address indexed to, uint256 amount);

    error BadLanding();

    constructor(address landing_, address owner_) Ownable(owner_) {
        if (landing_ == address(0)) revert BadLanding();
        landing = landing_;
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadLanding();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function sweepToken(address token) external onlyOwner returns (uint256 amt) {
        amt = IERC20(token).balanceOf(address(this));
        if (amt > 0) IERC20(token).safeTransfer(landing, amt);
        emit Swept(token, landing, amt);
    }

    function sweepFrom(address token, address from, uint256 amt) external onlyOwner {
        IERC20(token).safeTransferFrom(from, landing, amt);
        emit Swept(token, landing, amt);
    }

    receive() external payable {
        if (address(this).balance > 0) {
            (bool ok,) = landing.call{value: address(this).balance}("");
            require(ok, "ETH");
            emit Swept(address(0), landing, address(this).balance);
        }
    }
}
