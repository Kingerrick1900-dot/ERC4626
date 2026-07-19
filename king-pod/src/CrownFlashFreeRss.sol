// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFree {
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
        bytes memory data
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

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoFree {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
}

/// @notice Flash-close hot's self-looped RSS Morpho book → free ~18.5M RSS to king.
/// @dev REPAY_SOURCE = Morpho.withdraw(hot USDC supply) + yRSS.withdraw(gap).
///      Morpho flash fee = 0. Requires morpho.setAuthorization(this, true) + yRSS approve.
contract CrownFlashFreeRss is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFree public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IMetaMorphoFree public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoFree.MarketParams public mp;

    bool private _locking;

    event Freed(uint256 debtRepaid, uint256 supplyPulled, uint256 rssFreed, uint256 yrssUsed);

    error OnlyMorpho();
    error NotKing();
    error NoPos();
    error Short();

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
        morpho = IMorphoFree(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IMetaMorphoFree(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoFree.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Atomic free of king's RSS collateral. Named repay: own Morpho supply + yRSS.
    function freeRss() external onlyOwner nonReentrant {
        (uint256 supShares, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        if (borShares == 0 && coll == 0) revert NoPos();

        uint256 flashAmt = 0;
        if (borShares > 0) {
            // Accrue first so debt math matches repay(toAssetsUp) after IRM tick.
            morpho.accrueInterest(mp);
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
            // Fat buffer — stale lastUpdate can jump debt tens of USDC on $9M book
            flashAmt += 1_000e6; // +$1000
        }

        _locking = true;
        if (flashAmt > 0) {
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(supShares, uint256(borShares), uint256(coll)));
        } else if (coll > 0) {
            morpho.withdrawCollateral(mp, coll, king, king);
            emit Freed(0, 0, coll, 0);
        }
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        (uint256 supShares, uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256, uint256));

        usdc.approve(address(morpho), type(uint256).max);

        // 1) Close debt
        if (borShares > 0) {
            morpho.repay(mp, 0, borShares, king, "");
        }

        // 2) Pull king's USDC supply into this contract (named repay source)
        uint256 pulled;
        if (supShares > 0) {
            (pulled,) = morpho.withdraw(mp, 0, supShares, king, address(this));
        }

        // 3) Free RSS collateral to king
        if (coll > 0) {
            morpho.withdrawCollateral(mp, coll, king, king);
        }

        // 4) Cover flash from yRSS (now liquid — util collapsed after repay).
        //    Self-seed books have king Morpho supplyShares=0; almost all USDC sits in yRSS.
        //    Share/fee rounding can leave a small gap (~$100–$200 on a $9M book) — prefund
        //    this contract with a few hundred USDC before freeRss(), or Short() reverts.
        uint256 yrssUsed;
        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) {
            uint256 need = assets - have;
            uint256 maxW = yrss.maxWithdraw(king);
            uint256 pull = maxW < need ? maxW : need;
            if (pull > 0) {
                yrss.withdraw(pull, address(this), king);
                yrssUsed = pull;
            }
            have = usdc.balanceOf(address(this));
        }
        if (have < assets) revert Short();

        // Morpho pulls `assets` back via transferFrom after callback
        usdc.approve(address(morpho), assets);

        // Dust USDC left on this → king vault path: send to king
        uint256 dust = usdc.balanceOf(address(this)) - assets;
        if (dust > 0) usdc.safeTransfer(king, dust);

        emit Freed(borShares, pulled, coll, yrssUsed);
    }
}
