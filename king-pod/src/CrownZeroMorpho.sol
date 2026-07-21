// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoZ {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function accrueInterest(MarketParams memory marketParams) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IYrssZ {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
}

/// @notice Zero Morpho dust: flash → repay all shares → free all coll to king → yRSS covers flash.
contract CrownZeroMorpho is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoZ public immutable morpho;
    IERC20 public immutable usdc;
    IYrssZ public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoZ.MarketParams public mp;
    bool private _locking;

    error OnlyMorpho();
    error Short();
    error NoDebt();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address yrss_,
        address king_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoZ(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssZ(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoZ.MarketParams(usdc_, rss_, oracle_, irm_, lltv_);
    }

    function zeroBooks() external onlyOwner nonReentrant {
        morpho.accrueInterest(mp);
        (uint256 sup, uint128 bor, uint128 coll) = morpho.position(marketId, king);
        if (bor == 0 && coll == 0 && sup == 0) return;

        if (bor > 0) {
            // Flash exactly pro-rata debt. Do NOT pad (+$10 broke live: yRSS unlock ≈ debt only).
            (,, uint128 borrowAssets, uint128 borrowShares,,) = morpho.market(marketId);
            uint256 flashAmt = (uint256(borrowAssets) * uint256(bor) + uint256(borrowShares) - 1) / uint256(borrowShares);
            _locking = true;
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(sup), uint256(bor), uint256(coll)));
            _locking = false;
        } else if (coll > 0) {
            morpho.withdrawCollateral(mp, coll, king, king);
        }

        // Sweep any leftover yRSS liquidity to king (no recycle into Morpho)
        uint256 maxR = yrss.maxRedeem(king);
        if (maxR > 0) {
            yrss.redeem(maxR, king, king);
        }
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(king, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();
        (uint256 supShares, uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256, uint256));
        usdc.approve(address(morpho), type(uint256).max);
        if (borShares > 0) morpho.repay(mp, 0, borShares, king, "");
        if (coll > 0) morpho.withdrawCollateral(mp, coll, king, king);
        // King's direct Morpho supply (~$1 seed) unlocks once borrow is zero.
        if (supShares > 0) morpho.withdraw(mp, 0, supShares, king, address(this));

        _pullUsdcForFlash(assets);
        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.approve(address(morpho), assets);
    }

    /// @dev After repay, yRSS unlocks ~debt USDC. Pull hot wallet + any yRSS dust shares too.
    function _pullUsdcForFlash(uint256 assets) internal {
        uint256 have = usdc.balanceOf(address(this));
        if (have >= assets) return;

        uint256 need = assets - have;
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW > 0) {
            uint256 pull = maxW < need ? maxW : need;
            yrss.withdraw(pull, address(this), king);
            have = usdc.balanceOf(address(this));
            if (have >= assets) return;
            need = assets - have;
        }

        uint256 maxR = yrss.maxRedeem(king);
        if (maxR > 0 && need > 0) {
            yrss.redeem(maxR, address(this), king);
            have = usdc.balanceOf(address(this));
            if (have >= assets) return;
            need = assets - have;
        }

        uint256 kingBal = usdc.balanceOf(king);
        if (kingBal > 0 && need > 0) {
            uint256 take = kingBal < need ? kingBal : need;
            usdc.safeTransferFrom(king, address(this), take);
        }
    }
}
