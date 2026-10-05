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
}

/// @notice Move King's RSS from legacy Morpho market → sovereign CrownOracle market.
/// @dev Paths:
///   A) Treasury: King USDC (+ yRSS) covers full debt — no flash.
///   B) Flash + treasury bridge: Morpho flash (~available USDC) + King delta → repay →
///      yRSS unlocks → pull flash repay → withdraw RSS to migrator → approve(max) → supply sovereign.
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
    error TreasuryShort();

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

    function migrate() external onlyOwner nonReentrant {
        morpho.accrueInterest(_legacyMp());
        (, uint128 bor, uint128 coll) = morpho.position(legacyMarketId, king);
        if (bor == 0 && coll == 0) revert NothingToMigrate();

        if (bor > 0) {
            uint256 debt = _debtAssets(bor);
            if (_tryClearLegacyWithUsdc(bor, coll, debt)) {
                _supplyMigratorRssOnSovereign();
                _sweepKing();
                return;
            }
            // Path B: Morpho flash + King treasury delta
            uint256 morphoCash = usdc.balanceOf(address(morpho));
            if (morphoCash == 0 || debt == 0) revert NoFlashLiquidity();
            uint256 flashAmt = debt < morphoCash ? debt : morphoCash;
            uint256 delta = debt - flashAmt;
            if (delta > 0 && usdc.balanceOf(king) < delta) revert TreasuryShort();
            _inFlash = true;
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(delta, uint256(coll), uint256(bor)));
            _inFlash = false;
            _supplyMigratorRssOnSovereign();
        } else if (coll > 0) {
            morpho.withdrawCollateral(_legacyMp(), coll, king, address(this));
            _supplyMigratorRssOnSovereign();
        }
        _sweepKing();
    }

    /// @dev King / yRSS USDC on-hand (no flash): full repay → withdraw RSS to migrator.
    function _tryClearLegacyWithUsdc(uint128 bor, uint128 coll, uint256 debt) internal returns (bool) {
        if (bor == 0) return false;
        uint256 onHand = usdc.balanceOf(address(this)) + usdc.balanceOf(king);
        uint256 fromYrss = yrss.maxWithdraw(king);
        if (onHand + fromYrss < debt) return false;

        usdc.approve(address(morpho), type(uint256).max);
        uint256 have = usdc.balanceOf(address(this));
        if (have < debt) _pullYrssUsdc(debt - have);
        have = usdc.balanceOf(address(this));
        if (have < debt) {
            usdc.safeTransferFrom(king, address(this), debt - have);
        }
        morpho.repay(_legacyMp(), 0, bor, king, "");
        if (coll > 0) morpho.withdrawCollateral(_legacyMp(), coll, king, address(this));
        return true;
    }

    /// @dev 1) RSS on this contract 2) approve(MORPHO, max) 3) supply sovereign for King.
    function _supplyMigratorRssOnSovereign() internal {
        uint256 bal = rss.balanceOf(address(this));
        if (bal == 0) revert Short();
        rss.approve(address(morpho), type(uint256).max);
        morpho.supplyCollateral(_sovMp(), bal, king, "");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_inFlash) revert OnlyMorpho();
        (uint256 delta, uint256 coll, uint256 borShares) = abi.decode(data, (uint256, uint256, uint256));
        IMorphoMarket.MarketParams memory leg = _legacyMp();

        usdc.approve(address(morpho), type(uint256).max);

        // Treasury bridge: King supplies the flash shortfall
        if (delta > 0) usdc.safeTransferFrom(king, address(this), delta);

        // Repay legacy in full (shares)
        if (borShares > 0) morpho.repay(leg, 0, uint128(borShares), king, "");

        // Idle opens on legacy book → pull USDC from yRSS to repay flash (+ surplus to King via sweep)
        _pullYrssUsdc(type(uint256).max);

        // Withdraw 252k RSS to this migrator
        if (coll > 0) morpho.withdrawCollateral(leg, coll, king, address(this));

        // Fund flash repay (yRSS first, then King)
        _fundFlashRepay(assets);
        usdc.approve(address(morpho), assets);
    }

    function _pullYrssUsdc(uint256 budget) internal {
        if (budget == 0) return;
        uint256 pulled;
        while (pulled < budget) {
            uint256 maxW = yrss.maxWithdraw(king);
            if (maxW == 0) break;
            uint256 need = budget - pulled;
            uint256 chunk = need < maxW ? need : maxW;
            yrss.withdraw(chunk, address(this), king);
            pulled += chunk;
        }
    }

    function _fundFlashRepay(uint256 assets) internal {
        uint256 have = usdc.balanceOf(address(this));
        if (have >= assets) return;
        _pullYrssUsdc(assets - have);
        have = usdc.balanceOf(address(this));
        if (have < assets) {
            uint256 still = assets - have;
            uint256 kb = usdc.balanceOf(king);
            if (still > kb) still = kb;
            if (still > 0) usdc.safeTransferFrom(king, address(this), still);
            have = usdc.balanceOf(address(this));
        }
        if (have < assets) revert Short();
    }

    function _sweepKing() internal {
        uint256 u = usdc.balanceOf(address(this));
        if (u > 0) usdc.safeTransfer(king, u);
        uint256 r = rss.balanceOf(address(this));
        if (r > 0) rss.safeTransfer(king, r);
    }

    /// @notice King can revoke RSS approval on Morpho from this contract.
    function revokeRssApproval() external onlyOwner {
        rss.approve(address(morpho), 0);
    }
}
