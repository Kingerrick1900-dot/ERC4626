// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoNine {
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

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoNine {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice Atomic Move1+Move2: post RSS coll → flash USDC → deposit yRSS → borrow → repay flash.
/// @dev End state: king holds yRSS shares (= war chest in vault), Morpho debt = flash size,
///      RSS collateral posted. Liquid USDC in wallet = 0 (flash closes). Fee rail = yRSS 10%.
///      REPAY_SOURCE = Morpho.borrow(onBehalf king) against freshly posted RSS + yRSS-supplied depth.
contract CrownSelfSeedNine is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant ASK_USDC = 9_000_000e6; // $9M
    uint256 public constant MAX_LTV_BPS = 7000; // 70% soft cap vs oracle $1 RSS

    IMorphoNine public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IMetaMorphoNine public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoNine.MarketParams public mp;

    bool private _locking;

    event SelfSeeded(uint256 rssColl, uint256 usdcToYrss, uint256 borrowUsdc, uint256 yrssShares);

    error OnlyMorpho();
    error BadAmt();
    error Ltv();
    error NoAuthPath();

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
        morpho = IMorphoNine(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IMetaMorphoNine(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoNine.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @param rssAmount RSS to post (0 = full wallet balance of king, pulled via allowance)
    /// @param borrowUsdc USDC to seed/borrow (0 = ASK_USDC $9M)
    function selfSeed(uint256 rssAmount, uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc == 0) borrowUsdc = ASK_USDC;
        if (borrowUsdc < 1_000_000e6) revert BadAmt(); // min $1M — no dust

        if (rssAmount == 0) rssAmount = rss.balanceOf(king);
        // Oracle $1: LTV = borrow / rssAmount (both 1e18-scaled value in USD terms; USDC 6 dec)
        // borrowUsdc (6 dec) / 1e6 <= rssAmount/1e18 * 0.70
        // borrowUsdc * 1e18 <= rssAmount * 0.70 * 1e6
        if (borrowUsdc * 1e18 > (rssAmount * MAX_LTV_BPS * 1e6) / 10_000) revert Ltv();

        // Pull RSS → post as king's collateral
        rss.safeTransferFrom(king, address(this), rssAmount);
        rss.approve(address(morpho), rssAmount);
        morpho.supplyCollateral(mp, rssAmount, king, "");

        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(rssAmount, borrowUsdc));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 rssAmount, uint256 borrowUsdc) = abi.decode(data, (uint256, uint256));
        if (assets != borrowUsdc) revert BadAmt();

        // Move 2: seed yRSS (supply queue[0] = RSS market) — shares to king
        usdc.approve(address(yrss), assets);
        uint256 shares = yrss.deposit(assets, king);

        // Market now has idle from yRSS supply → borrow against king's RSS to repay flash
        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert NoAuthPath();

        morpho.borrow(mp, assets, 0, king, address(this));

        usdc.approve(address(morpho), assets);
        emit SelfSeeded(rssAmount, assets, assets, shares);
    }
}
