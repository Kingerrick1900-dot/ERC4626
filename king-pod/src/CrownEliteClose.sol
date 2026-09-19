// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoElite {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

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

interface ICrownSeedFill {
    function fillSellRss(uint256 rssAmount, uint256 minUsdcOut, address usdcReceiver) external returns (uint256 usdcOut);
    function priceUsdcPerRss() external view returns (uint256);
}

/// @notice Elite vault load: borrow full USDC stack to treasury, repay Morpho via RSS sell, debt cleared.
/// @dev Sole vault = `treasury` (receiver). No ops drip. No caps. Full amount in one tx.
contract CrownEliteClose is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoElite public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    ICrownSeedFill public immutable fill;
    address public immutable king;
    bytes32 public immutable marketId;

    address public treasury;

    IMorphoElite.MarketParams public marketParams;

    bool private _inElite;
    uint256 private _borrowB;
    uint256 private _rssForFill;

    event EliteClosed(uint256 borrowUsdc, uint256 rssSold, uint256 vaultUsdcAfter);
    event TreasurySet(address treasury);

    error Zero();
    error Auth();
    error FillShort();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address fill_,
        address king_,
        address treasury_,
        IMorphoElite.MarketParams memory params_,
        address owner_
    ) Ownable(owner_) {
        if (king_ == address(0) || treasury_ == address(0)) revert Zero();
        morpho = IMorphoElite(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        fill = ICrownSeedFill(fill_);
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

    /// @notice Full stack → treasury in one tx. Morpho debt cleared. No drip.
    function eliteClose(uint256 rssCollateral, uint256 borrowUsdc, uint256 rssForFill)
        external
        onlyOwner
        nonReentrant
    {
        if (rssCollateral == 0 || borrowUsdc == 0 || rssForFill == 0) revert Zero();
        if (rssForFill > rssCollateral) revert Zero();

        uint256 expectedUsdc = (rssForFill * fill.priceUsdcPerRss()) / 1e18;
        if (expectedUsdc < borrowUsdc) revert FillShort();

        rss.safeTransferFrom(king, address(this), rssCollateral);
        rss.safeApprove(address(morpho), rssCollateral);

        morpho.supplyCollateral(marketParams, rssCollateral, king, bytes(""));
        morpho.borrow(marketParams, borrowUsdc, 0, king, treasury);

        _inElite = true;
        _borrowB = borrowUsdc;
        _rssForFill = rssForFill;
        morpho.flashLoan(address(usdc), borrowUsdc, bytes(""));
        _inElite = false;
        _borrowB = 0;
        _rssForFill = 0;

        emit EliteClosed(borrowUsdc, rssForFill, usdc.balanceOf(treasury));

        uint256 dust = rss.balanceOf(address(this));
        if (dust > 0) rss.safeTransfer(king, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho) || !_inElite) revert Auth();

        uint256 B = _borrowB;
        uint256 sellRss = _rssForFill;
        require(assets == B, "FLASH");

        usdc.safeApprove(address(morpho), B);
        morpho.repay(marketParams, B, 0, king, bytes(""));

        morpho.withdrawCollateral(marketParams, sellRss, king, address(this));

        rss.safeApprove(address(fill), sellRss);
        uint256 usdcOut = fill.fillSellRss(sellRss, B, address(this));
        if (usdcOut < B) revert FillShort();

        (, , uint128 collLeft) = morpho.position(marketId, king);
        if (collLeft > 0) {
            morpho.withdrawCollateral(marketParams, uint256(collLeft), king, king);
        }

        usdc.safeApprove(address(morpho), assets);
    }
}
