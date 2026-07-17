// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFlash {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Flash Morpho open: flash → supply → RSS collateral → borrow → repay flash.
/// @dev Peapods-style book control. No King USDC required for the open.
contract CrownFlashOpen is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFlash public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoFlash.MarketParams public marketParams;

    bool private _open;
    uint256 private _rssAmount;

    event FlashOpened(uint256 rssCollateral, uint256 flashUsdc);

    error Zero();
    error Auth();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        IMorphoFlash.MarketParams memory params_,
        address owner_
    ) Ownable(owner_) {
        if (king_ == address(0)) revert Zero();
        morpho = IMorphoFlash(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        king = king_;
        marketParams = params_;
        marketId = keccak256(abi.encode(params_));
    }

    function flashOpen(uint256 rssAmount, uint256 flashUsdc) external onlyOwner nonReentrant {
        if (rssAmount == 0 || flashUsdc == 0) revert Zero();
        _open = true;
        _rssAmount = rssAmount;
        morpho.flashLoan(address(usdc), flashUsdc, bytes(""));
        _open = false;
        _rssAmount = 0;
        emit FlashOpened(rssAmount, flashUsdc);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho) || !_open) revert Auth();
        uint256 rssAmount = _rssAmount;

        rss.safeTransferFrom(king, address(this), rssAmount);
        usdc.safeApprove(address(morpho), type(uint256).max);
        rss.safeApprove(address(morpho), type(uint256).max);

        morpho.supply(marketParams, assets, 0, king, bytes(""));
        morpho.supplyCollateral(marketParams, rssAmount, king, bytes(""));
        morpho.borrow(marketParams, assets, 0, king, address(this));

        usdc.safeApprove(address(morpho), assets);
    }
}
