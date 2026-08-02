// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoComfort {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoComfort {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice Comfort self-seed — Morpho-legal matched book, customized for King sit.
/// @dev - Folds existing dust coll/debt into one seat
///      - `rssKeep` leaves free RSS on king
///      - Optional `sleeveUsdc` → util = borrow/(borrow+sleeve)
///      - Soft LTV default ~48.6%; hard cap 70%
///      - Never touches kUSD / other non-USDC stables
contract CrownComfortSeed is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant MAX_LTV_BPS = 7000;
    uint256 public constant DEFAULT_TARGET_LTV_BPS = 4860;

    IMorphoComfort public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IMetaMorphoComfort public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoComfort.MarketParams public mp;

    bool private _locking;

    event ComfortSeeded(
        uint256 rssPosted,
        uint256 rssKept,
        uint256 flashUsdc,
        uint256 sleeveUsdc,
        uint256 yrssShares,
        uint256 targetLtvBps
    );

    error OnlyMorpho();
    error BadAmt();
    error Ltv();
    error NoIdle();
    error KeepTooHigh();

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
        morpho = IMorphoComfort(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IMetaMorphoComfort(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoComfort.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    function _debtAssets(address user) internal view returns (uint256) {
        (, uint128 borrowShares,) = morpho.position(marketId, user);
        if (borrowShares == 0) return 0;
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(marketId);
        if (totalBorrowShares == 0) return 0;
        return (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1)
            / uint256(totalBorrowShares);
    }

    /// @param rssKeep Free RSS left on king wallet
    /// @param borrowUsdc Flash size (0 = auto to target LTV on total coll after post, net of dust debt)
    /// @param sleeveUsdc Extra king USDC into yRSS for idle sleeve
    /// @param targetLtvBps Soft LTV when auto-sizing
    function comfortSeed(uint256 rssKeep, uint256 borrowUsdc, uint256 sleeveUsdc, uint256 targetLtvBps)
        external
        onlyOwner
        nonReentrant
    {
        if (targetLtvBps == 0) targetLtvBps = DEFAULT_TARGET_LTV_BPS;
        if (targetLtvBps > MAX_LTV_BPS) targetLtvBps = MAX_LTV_BPS;

        uint256 walletRss = rss.balanceOf(king);
        if (rssKeep > walletRss) revert KeepTooHigh();
        uint256 toPost = walletRss - rssKeep;

        (, , uint128 collAlready) = morpho.position(marketId, king);
        uint256 totalCollAfter = uint256(collAlready) + toPost;
        if (totalCollAfter == 0) revert BadAmt();

        uint256 existingDebt = _debtAssets(king);
        uint256 maxDebt = (totalCollAfter * targetLtvBps) / (10_000 * 1e12);

        if (borrowUsdc == 0) {
            if (existingDebt >= maxDebt) revert BadAmt();
            borrowUsdc = maxDebt - existingDebt;
        }

        if (borrowUsdc < 100_000e6) revert BadAmt();

        uint256 projectedDebt = existingDebt + borrowUsdc;
        uint256 hardMax = (totalCollAfter * MAX_LTV_BPS) / (10_000 * 1e12);
        if (projectedDebt > hardMax) revert Ltv();

        if (sleeveUsdc > 0) {
            usdc.safeTransferFrom(king, address(this), sleeveUsdc);
        }

        if (toPost > 0) {
            rss.safeTransferFrom(king, address(this), toPost);
            rss.approve(address(morpho), toPost);
            morpho.supplyCollateral(mp, toPost, king, "");
        }

        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(toPost, rssKeep, borrowUsdc, sleeveUsdc, targetLtvBps));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 toPost, uint256 rssKeep, uint256 borrowUsdc, uint256 sleeveUsdc, uint256 targetLtvBps) =
            abi.decode(data, (uint256, uint256, uint256, uint256, uint256));
        if (assets != borrowUsdc) revert BadAmt();

        uint256 depositAmt = assets + sleeveUsdc;
        usdc.approve(address(yrss), depositAmt);
        uint256 shares = yrss.deposit(depositAmt, king);

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert NoIdle();

        morpho.borrow(mp, assets, 0, king, address(this));

        usdc.approve(address(morpho), assets);
        emit ComfortSeeded(toPost, rssKeep, assets, sleeveUsdc, shares, targetLtvBps);
    }
}
