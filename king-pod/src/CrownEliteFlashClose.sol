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

interface IDeskSeed {
    function seed(uint256 usdcAmount) external;
}

/// @notice Elite flash close with auto rail reload.
/// @dev Every landed USDC is split in-tx: `railBps` auto-seeds the desk (next round fuel),
///      remainder goes to kingdom vault. Default railBps = 100% so rails never go dry mid-run.
contract CrownEliteFlashClose is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant BPS = 10_000;

    IMorphoFlashElite public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    ICrownSeedFillFlash public immutable fill;
    IDeskSeed public immutable desk;
    address public immutable king;
    bytes32 public immutable marketId;

    address public treasury;
    /// @notice Share of each landing that auto-seeds the desk rail. 10000 = all to rails.
    uint256 public railBps = BPS;

    IMorphoFlashElite.MarketParams public marketParams;

    bool private _inElite;
    uint256 private _borrowB;
    uint256 private _rssForFill;
    uint256 private _rssCollateral;

    event EliteFlashClosed(
        uint256 borrowUsdc, uint256 rssSold, uint256 vaultPaid, uint256 railSeeded, uint256 flashUsdc
    );
    event TreasurySet(address treasury);
    event RailBpsSet(uint256 railBps);

    error Zero();
    error Auth();
    error FillShort();
    error FlashSize();
    error Bps();

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
        if (king_ == address(0) || treasury_ == address(0) || fill_ == address(0)) revert Zero();
        morpho = IMorphoFlashElite(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        fill = ICrownSeedFillFlash(fill_);
        desk = IDeskSeed(fill_);
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

    function setRailBps(uint256 bps) external onlyOwner {
        if (bps > BPS) revert Bps();
        railBps = bps;
        emit RailBpsSet(bps);
    }

    /// @notice Fire one round. Landed USDC auto-loads rails (railBps) + vault (remainder).
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

        // Landed B sits here after flash repay - auto-split to rails + vault.
        uint256 landed = usdc.balanceOf(address(this));
        uint256 railSeeded;
        uint256 vaultPaid;
        if (landed > 0) {
            railSeeded = (landed * railBps) / BPS;
            vaultPaid = landed - railSeeded;
            if (railSeeded > 0) {
                usdc.safeApprove(address(desk), railSeeded);
                desk.seed(railSeeded);
            }
            if (vaultPaid > 0) {
                usdc.safeTransfer(treasury, vaultPaid);
            }
        }

        emit EliteFlashClosed(borrowUsdc, rssForFill, vaultPaid, railSeeded, flashUsdc);

        uint256 dust = rss.balanceOf(address(this));
        if (dust > 0) rss.safeTransfer(king, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho) || !_inElite) revert Auth();

        uint256 B = _borrowB;
        uint256 sellRss = _rssForFill;
        uint256 collRss = _rssCollateral;
        if (assets != B * 2) revert FlashSize();

        usdc.safeApprove(address(morpho), B);
        morpho.supply(marketParams, B, 0, king, bytes(""));

        rss.safeTransferFrom(king, address(this), collRss);
        rss.safeApprove(address(morpho), collRss);
        morpho.supplyCollateral(marketParams, collRss, king, bytes(""));
        // Borrow to this closer - split to rails/vault after flash settles.
        morpho.borrow(marketParams, B, 0, king, address(this));

        usdc.safeApprove(address(morpho), B);
        morpho.repay(marketParams, B, 0, king, bytes(""));

        morpho.withdraw(marketParams, B, 0, king, address(this));

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
