// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoU {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Unwind King Morpho self-lend: flash → repay debt → withdraw supply → return RSS → repay flash.
/// @dev King owes nobody after this. No vault touch.
contract CrownUnwind is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoU public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoU.MarketParams public marketParams;

    bool private _in;

    event Unwound(uint256 debtRepaid, uint256 supplyOut, uint256 rssOut);

    error Auth();
    error Zero();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        IMorphoU.MarketParams memory params_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoU(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        king = king_;
        marketParams = params_;
        marketId = keccak256(abi.encode(params_));
    }

    function unwind() external onlyOwner nonReentrant {
        (, uint128 borrowShares,) = morpho.position(marketId, king);
        if (borrowShares == 0) revert Zero();

        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(marketId);
        // ceil borrow assets from shares + $1 buffer for accrual in-flight
        uint256 assets = (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1)
            / uint256(totalBorrowShares);
        assets += 1e6;

        _in = true;
        morpho.flashLoan(address(usdc), assets, bytes(""));
        _in = false;

        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(king, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho) || !_in) revert Auth();

        usdc.safeApprove(address(morpho), type(uint256).max);

        (uint256 supplyShares, uint128 borrowShares, uint128 coll) = morpho.position(marketId, king);

        // Full debt clear by shares
        uint256 debtRepaid;
        if (borrowShares > 0) {
            (debtRepaid,) = morpho.repay(marketParams, 0, uint256(borrowShares), king, bytes(""));
        }

        // Pull all supply back
        uint256 supplyOut;
        if (supplyShares > 0) {
            (supplyOut,) = morpho.withdraw(marketParams, 0, supplyShares, king, address(this));
        }

        // Free all RSS collateral to King
        if (coll > 0) {
            morpho.withdrawCollateral(marketParams, uint256(coll), king, king);
        }

        // Repay flash; leftover USDC → King
        usdc.safeApprove(address(morpho), assets);
        uint256 left = usdc.balanceOf(address(this));
        // Morpho pulls `assets` after callback; ensure we hold >= assets
        // Any surplus after Morpho pull stays here — send dust to king in unwind() end
        emit Unwound(debtRepaid, supplyOut, uint256(coll));
        left; // silence
    }

    function sweep(address token, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
    }
}
