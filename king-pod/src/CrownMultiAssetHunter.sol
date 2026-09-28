// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface ICrownHuntRouter {
    function hunt(
        address token,
        uint256 assets,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        uint256 tipErc20
    ) external payable;

    function setTarget(address t, bool ok) external;
    function setHunter(address h, bool ok) external;
}

/// @title CrownMultiAssetHunter
/// @notice Flash-hunt bot for WETH / cbBTC / USDC — profits sweep to HOT.
/// @dev Does not touch yRSS/PARK gold. Owner = King HOT. Router must setHunter(this).
contract CrownMultiAssetHunter is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    ICrownHuntRouter public immutable router;
    address public immutable hot;
    IERC20 public immutable weth;
    IERC20 public immutable cbbtc;
    IERC20 public immutable usdc;

    event HuntExec(address indexed token, uint256 assets, address indexed caller);
    event Swept(address indexed token, uint256 amt);

    error Zero();

    constructor(address router_, address hot_, address weth_, address cbbtc_, address usdc_, address owner_)
        Ownable(owner_)
    {
        if (router_ == address(0) || hot_ == address(0)) revert Zero();
        router = ICrownHuntRouter(router_);
        hot = hot_;
        weth = IERC20(weth_);
        cbbtc = IERC20(cbbtc_);
        usdc = IERC20(usdc_);
    }

    /// @notice Execute allowlisted hunt path; flash token from Morpho via HuntRouter.
    function exec(
        address token,
        uint256 assets,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        uint256 tipErc20
    ) external payable onlyOwner nonReentrant {
        router.hunt{value: msg.value}(token, assets, targets, values, datas, tipErc20);
        emit HuntExec(token, assets, msg.sender);
        _sweepAll();
    }

    /// @notice Smoke path — flash + no-op targets (Morpho 0-fee repay). Proves multi-asset pipe.
    function smoke(address token, uint256 assets) external onlyOwner nonReentrant {
        address[] memory t;
        uint256[] memory v;
        bytes[] memory d;
        router.hunt(token, assets, t, v, d, 0);
        emit HuntExec(token, assets, msg.sender);
    }

    function sweep() external onlyOwner {
        _sweepAll();
    }

    function _sweepAll() internal {
        _sweepToken(address(weth));
        _sweepToken(address(cbbtc));
        _sweepToken(address(usdc));
        uint256 ethBal = address(this).balance;
        if (ethBal > 0) {
            (bool ok,) = hot.call{value: ethBal}("");
            require(ok, "ETH");
            emit Swept(address(0), ethBal);
        }
    }

    function _sweepToken(address token) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) return;
        IERC20(token).safeTransfer(hot, bal);
        emit Swept(token, bal);
    }

    receive() external payable {}
}
