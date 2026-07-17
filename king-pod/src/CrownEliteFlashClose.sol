// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFlashElite {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
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

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface ICrownSeedFillFlash {
    function fillSellRss(uint256 rssAmount, uint256 minUsdcOut, address usdcReceiver) external returns (uint256 usdcOut);
    function priceUsdcPerRss() external view returns (uint256);
}

/// @notice Capital-halving elite vault load.
/// @dev Flashes 2×B from Morpho's global USDC float, self-supplies the Morpho rail,
///      borrows B to treasury, clears debt, sells RSS into desk for B, repays flash.
///      Seat capital needed = desk B only (not desk B + Morpho B).
contract CrownEliteFlashClose is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFlashElite public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    ICrownSeedFillFlash public immutable fill;
    address public immutable king;
    bytes32 public immutable marketId;

    address public treasury;

    IMorphoFlashElite.MarketParams public marketParams;

    bool private _inElite;
    uint256 private _borrowB;
    uint256 private _rssForFill;
    uint256 private _rssCollateral;

    event EliteFlashClosed(uint256 borrowUsdc, uint256 rssSold, uint256 vaultUsdcAfter, uint256 flashUsdc);
    event TreasurySet(address treasury);

    error Zero();
    error Auth();
    error FillShort();
    error FlashSize();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address fill_,
        address king_,
        address treasury_,
        IMorphoFlashElite.MarketParams memory params_,
        address owner_
    ) Ownable(owner_) {
        if (king_ == address(0) || treasury_ == address(0)) revert Zero();
        morpho = IMorphoFlashElite(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        fill = ICrownSeedFillFlash(fill_);
        king = king_;
        treasury = treasury_;
        marketParams = params_;
        marketId = keccak256(abi.encode(params_));
    }

    function setTreasury(address t) external onlyOwner {
        if (t == address(0)) revert Zero();
        treasury = t;
        emit TreasurySet(t);
    }

    /// @notice Vault +B in one tx. Desk needs B. Morpho rail is flashed (no Morpho pre-fund).
    function eliteFlashClose(uint256 rssCollateral, uint256 borrowUsdc, uint256 rssForFill)
        external
        onlyOwner
        nonReentrant
    {
        if (rssCollateral == 0 || borrowUsdc == 0 || rssForFill == 0) revert Zero();
        if (rssForFill > rssCollateral) revert Zero();

        uint256 expectedUsdc = (rssForFill * fill.priceUsdcPerRss()) / 1e18;
        if (expectedUsdc < borrowUsdc) revert FillShort();

        uint256 flashUsdc = borrowUsdc * 2;

        _inElite = true;
        _borrowB = borrowUsdc;
        _rssForFill = rssForFill;
        _rssCollateral = rssCollateral;
        morpho.flashLoan(address(usdc), flashUsdc, bytes(""));
        _inElite = false;
        _borrowB = 0;
        _rssForFill = 0;
        _rssCollateral = 0;

        emit EliteFlashClosed(borrowUsdc, rssForFill, usdc.balanceOf(treasury), flashUsdc);

        uint256 dust = rss.balanceOf(address(this));
        if (dust > 0) rss.safeTransfer(king, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho) || !_inElite) revert Auth();

        uint256 B = _borrowB;
        uint256 sellRss = _rssForFill;
        uint256 collRss = _rssCollateral;
        if (assets != B * 2) revert FlashSize();

        // 1) Temporary Morpho rail from flash (no pre-fund).
        usdc.safeApprove(address(morpho), B);
        morpho.supply(marketParams, B, 0, king, bytes(""));

        // 2) Post RSS + borrow full stack straight to kingdom vault.
        rss.safeTransferFrom(king, address(this), collRss);
        rss.safeApprove(address(morpho), collRss);
        morpho.supplyCollateral(marketParams, collRss, king, bytes(""));
        morpho.borrow(marketParams, B, 0, king, treasury);

        // 3) Clear Morpho debt with the other half of the flash.
        usdc.safeApprove(address(morpho), B);
        morpho.repay(marketParams, B, 0, king, bytes(""));

        // 4) Pull temporary rail back.
        morpho.withdraw(marketParams, B, 0, king, address(this));

        // 5) Sell RSS into desk → second B to repay flash.
        morpho.withdrawCollateral(marketParams, sellRss, king, address(this));
        rss.safeApprove(address(fill), sellRss);
        uint256 usdcOut = fill.fillSellRss(sellRss, B, address(this));
        if (usdcOut < B) revert FillShort();

        (, , uint128 collLeft) = morpho.position(marketId, king);
        if (collLeft > 0) {
            morpho.withdrawCollateral(marketParams, uint256(collLeft), king, king);
        }

        // Morpho pulls `assets` (= 2B) via transferFrom after callback.
        usdc.safeApprove(address(morpho), assets);
    }
}
