// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable} from "./lib/Core.sol";
import {IRwaSwapper} from "./CrownRwaLoop.sol";

interface IUniLikeRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/// @notice Thin Aerodrome/Solidly-style adapter USDC ↔ RWA. Owner sets route legs.
contract RwaSwapAdapter is Ownable, IRwaSwapper {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable rwa;
    IUniLikeRouter public router;
    address public factory;
    bool public stable;

    event RouterSet(address router, address factory, bool stable);

    error Bad();

    constructor(address usdc_, address rwa_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        rwa = IERC20(rwa_);
    }

    function setRouter(address router_, address factory_, bool stable_) external onlyOwner {
        if (router_ == address(0)) revert Bad();
        router = IUniLikeRouter(router_);
        factory = factory_;
        stable = stable_;
        emit RouterSet(router_, factory_, stable_);
    }

    function usdcToRwa(uint256 usdcIn, uint256 minRwaOut) external returns (uint256 rwaOut) {
        if (address(router) == address(0) || usdcIn == 0) revert Bad();
        usdc.safeTransferFrom(msg.sender, address(this), usdcIn);
        usdc.safeApprove(address(router), 0);
        usdc.safeApprove(address(router), usdcIn);
        IUniLikeRouter.Route[] memory routes = new IUniLikeRouter.Route[](1);
        routes[0] = IUniLikeRouter.Route({from: address(usdc), to: address(rwa), stable: stable, factory: factory});
        uint256[] memory amts =
            router.swapExactTokensForTokens(usdcIn, minRwaOut, routes, msg.sender, block.timestamp + 600);
        rwaOut = amts[amts.length - 1];
    }

    function rwaToUsdc(uint256 rwaIn, uint256 minUsdcOut) external returns (uint256 usdcOut) {
        if (address(router) == address(0) || rwaIn == 0) revert Bad();
        rwa.safeTransferFrom(msg.sender, address(this), rwaIn);
        rwa.safeApprove(address(router), 0);
        rwa.safeApprove(address(router), rwaIn);
        IUniLikeRouter.Route[] memory routes = new IUniLikeRouter.Route[](1);
        routes[0] = IUniLikeRouter.Route({from: address(rwa), to: address(usdc), stable: stable, factory: factory});
        uint256[] memory amts =
            router.swapExactTokensForTokens(rwaIn, minUsdcOut, routes, msg.sender, block.timestamp + 600);
        usdcOut = amts[amts.length - 1];
    }
}
