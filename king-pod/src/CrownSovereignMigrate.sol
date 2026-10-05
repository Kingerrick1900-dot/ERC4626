// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {IMorphoMarket} from "./interfaces/IMorphoMarket.sol";

interface IMorphoM is IMorphoMarket {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory marketParams) external;
}

interface IMorphoFlashLoanCallbackM {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IYrssM {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @notice Path B — self-fund: Morpho flash + King yRSS equity. Path A (King treasury) REMOVED.
/// @dev Cannot borrow on sovereign market first: RSS locked on legacy; sovereign book has no lenders.
///      Debt is Morpho borrow funded by yRSS suppliers — not King wallet USDC.
contract CrownSovereignMigrate is Ownable, ReentrancyGuard, IMorphoFlashLoanCallbackM {
    using SafeTransfer for IERC20;

    IMorphoM public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IYrssM public immutable yrss;
    address public immutable king;
    bytes32 public immutable legacyMarketId;
    bytes32 public immutable sovereignMarketId;
    address public immutable legacyOracle;
    address public immutable sovereignOracle;
    address public immutable irm;
    uint256 public immutable lltv;

    bool private _inFlash;

    error OnlyMorpho();
    error Short();
    error NothingToMigrate();
    error NoFlashLiquidity();
    error SystemShort();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address yrss_,
        address king_,
        bytes32 legacyMarketId_,
        address legacyOracle_,
        bytes32 sovereignMarketId_,
        address sovereignOracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoM(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IYrssM(yrss_);
        king = king_;
        legacyMarketId = legacyMarketId_;
        legacyOracle = legacyOracle_;
        sovereignMarketId = sovereignMarketId_;
        sovereignOracle = sovereignOracle_;
        irm = irm_;
        lltv = lltv_;
    }

    function _legacyMp() internal view returns (IMorphoMarket.MarketParams memory) {
        return IMorphoMarket.MarketParams(address(usdc), address(rss), legacyOracle, irm, lltv);
    }

    function _sovMp() internal view returns (IMorphoMarket.MarketParams memory) {
        return IMorphoMarket.MarketParams(address(usdc), address(rss), sovereignOracle, irm, lltv);
    }

    function _debtAssets(uint128 borShares) internal view returns (uint256) {
        if (borShares == 0) return 0;
        (,, uint128 tba, uint128 tbs,,) = morpho.market(legacyMarketId);
        return (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
    }

    /// @notice Self-fund migrate. No King wallet USDC.
    function migrate() external onlyOwner nonReentrant {
        morpho.accrueInterest(_legacyMp());
        (, uint128 bor, uint128 coll) = morpho.position(legacyMarketId, king);
        if (bor == 0 && coll == 0) revert NothingToMigrate();

        if (bor > 0) {
            uint256 debt = _debtAssets(bor);
            uint256 morphoCash = usdc.balanceOf(address(morpho));
            if (morphoCash == 0 || debt == 0) revert NoFlashLiquidity();

            // King must own enough yRSS assets to settle debt through the vault (system capital).
            uint256 kingYrss = yrss.convertToAssets(yrss.balanceOf(king));
            if (kingYrss < debt) revert SystemShort();

            uint256 flashAmt = debt < morphoCash ? debt : morphoCash;
            _inFlash = true;
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(coll)));
            _inFlash = false;
            _supplyMigratorRssOnSovereign();
        } else if (coll > 0) {
            morpho.withdrawCollateral(_legacyMp(), coll, king, address(this));
            _supplyMigratorRssOnSovereign();
        }
        _sweepKing();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_inFlash) revert OnlyMorpho();
        uint256 coll = abi.decode(data, (uint256));
        IMorphoMarket.MarketParams memory leg = _legacyMp();

        usdc.approve(address(morpho), type(uint256).max);

        // 1) Partial/full repay with flash — opens market idle
        uint256 cash = usdc.balanceOf(address(this));
        if (cash > 0) morpho.repay(leg, cash, 0, king, "");

        // 2) Drain King yRSS liquidity (loop: idle unlocks in waves as we repay)
        _pullAllYrss();

        // 3) Finish legacy debt from yRSS proceeds
        (, uint128 borRem,) = morpho.position(legacyMarketId, king);
        if (borRem > 0) {
            if (usdc.balanceOf(address(this)) < _debtAssets(borRem)) {
                _pullAllYrss();
            }
            if (usdc.balanceOf(address(this)) < _debtAssets(borRem)) revert SystemShort();
            morpho.repay(leg, 0, borRem, king, "");
        }

        // 4) More idle may open after final repay — pull again for flash coverage
        _pullAllYrss();

        // 5) RSS to migrator
        (, , uint128 collRem) = morpho.position(legacyMarketId, king);
        if (collRem > 0) morpho.withdrawCollateral(leg, collRem, king, address(this));
        if (coll > 0 && rss.balanceOf(address(this)) == 0) revert Short();

        // 6) Flash repay from yRSS proceeds only
        if (usdc.balanceOf(address(this)) < assets) {
            _pullAllYrss();
        }
        if (usdc.balanceOf(address(this)) < assets) revert SystemShort();
        usdc.approve(address(morpho), assets);
    }

    function _supplyMigratorRssOnSovereign() internal {
        uint256 bal = rss.balanceOf(address(this));
        if (bal == 0) revert Short();
        rss.approve(address(morpho), type(uint256).max);
        morpho.supplyCollateral(_sovMp(), bal, king, "");
    }

    function _pullAllYrss() internal {
        for (uint256 i = 0; i < 8; i++) {
            uint256 maxW = yrss.maxWithdraw(king);
            if (maxW == 0) break;
            yrss.withdraw(maxW, address(this), king);
        }
    }

    function _sweepKing() internal {
        uint256 u = usdc.balanceOf(address(this));
        if (u > 0) usdc.safeTransfer(king, u);
        uint256 r = rss.balanceOf(address(this));
        if (r > 0) rss.safeTransfer(king, r);
    }

    function revokeRssApproval() external onlyOwner {
        rss.approve(address(morpho), 0);
    }
}
