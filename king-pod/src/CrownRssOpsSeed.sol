// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoOps {
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
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoOps {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice Desk-free ops seed: post RSS → flash USDC → yRSS.deposit → borrow → repay flash.
/// @dev End state: yRSS shares on king (reinvest war chest) + Morpho debt + RSS collateral.
///      Liquid wallet USDC stays ~0 after flash close. Fee rail = yRSS 10% → KingVault.
///      Size band: $600k–$700k (nation ops/reinvest ask). Elepan never touched.
contract CrownRssOpsSeed is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant MIN_USDC = 600_000e6;
    uint256 public constant MAX_USDC = 700_000e6;
    uint256 public constant MAX_LTV_BPS = 7000; // 70% soft cap vs $1 oracle

    IMorphoOps public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IMetaMorphoOps public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoOps.MarketParams public mp;

    bool private _locking;

    event OpsSeeded(uint256 rssColl, uint256 usdcToYrss, uint256 borrowUsdc, uint256 yrssShares);

    error OnlyMorpho();
    error BadAmt();
    error Ltv();
    error NoIdle();

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
        morpho = IMorphoOps(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IMetaMorphoOps(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoOps.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @param rssAmount RSS to post (0 = full king balance)
    /// @param borrowUsdc USDC seed size (0 = MAX 700k)
    function opsSeed(uint256 rssAmount, uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc == 0) borrowUsdc = MAX_USDC;
        if (borrowUsdc < MIN_USDC || borrowUsdc > MAX_USDC) revert BadAmt();

        if (rssAmount == 0) rssAmount = rss.balanceOf(king);
        // borrowUsdc * 1e18 <= rssAmount * 0.70 * 1e6
        if (borrowUsdc * 1e18 > (rssAmount * MAX_LTV_BPS * 1e6) / 10_000) revert Ltv();

        rss.safeTransferFrom(king, address(this), rssAmount);
        rss.approve(address(morpho), rssAmount);
        morpho.supplyCollateral(mp, rssAmount, king, "");

        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(borrowUsdc));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        uint256 borrowUsdc = abi.decode(data, (uint256));
        if (assets != borrowUsdc) revert BadAmt();

        usdc.approve(address(yrss), assets);
        uint256 shares = yrss.deposit(assets, king);

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert NoIdle();

        morpho.borrow(mp, assets, 0, king, address(this));
        usdc.approve(address(morpho), assets);
        emit OpsSeeded(0, assets, assets, shares);
    }
}
