// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoChunk {
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

interface IMetaMorphoChunk {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
}

/// @notice Chunk-unwind Morpho self-seed → free almost all RSS to king hot.
/// @dev NO re-lock path. Does not supply, borrow, self-seed, or deposit yRSS.
///      Leaves a tiny dust debt (~$300) so no USDC prefund is required.
///      RSS receiver is always `king` — never a vault/desk/pair.
contract CrownChunkFreeRss is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoChunk public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IMetaMorphoChunk public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoChunk.MarketParams public mp;

    uint256 public constant CHUNK = 1_000_000e6; // $1M
    uint256 public constant DUST_DEBT = 300e6; // leave ~$300 debt (avoids rounding Short)
    uint256 public constant COLL_BUFFER = 400 ether; // ~400 RSS stay posted vs dust

    bool private _locking;
    uint256 private _repayAssets;

    event ChunkFreed(uint256 chunk, uint256 debtLeft);
    event RssFreedToKing(uint256 rssAmount, uint256 dustDebtLeft, uint256 dustCollLeft);

    error OnlyMorpho();
    error NoPos();
    error Short();
    error RecycleForbidden();

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
        morpho = IMorphoChunk(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IMetaMorphoChunk(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoChunk.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Free RSS to king hot only. Does not open any new locked position.
    function freeRssToKing() external onlyOwner nonReentrant {
        (, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        if (borShares == 0 && coll == 0) revert NoPos();

        // 1) Chunk-repay until only dust debt remains (no USDC prefund needed)
        for (uint256 i; i < 20; i++) {
            morpho.accrueInterest(mp);
            (, uint128 bor,) = morpho.position(marketId, king);
            if (bor == 0) break;

            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            uint256 debt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
            if (debt <= DUST_DEBT) break;

            uint256 chunk = debt - DUST_DEBT;
            if (chunk > CHUNK) chunk = CHUNK;

            _repayAssets = chunk;
            _locking = true;
            morpho.flashLoan(address(usdc), chunk, "");
            _locking = false;
            emit ChunkFreed(chunk, debt - chunk);
        }

        // 2) Withdraw excess collateral → king hot ONLY
        morpho.accrueInterest(mp);
        (, uint128 bor2, uint128 coll2) = morpho.position(marketId, king);
        uint256 debtLeft;
        if (bor2 > 0) {
            (,, uint128 tba2, uint128 tbs2,,) = morpho.market(marketId);
            debtLeft = (uint256(tba2) * uint256(bor2) + uint256(tbs2) - 1) / uint256(tbs2);
        }

        uint256 keep = COLL_BUFFER;
        if (debtLeft > 0) {
            // keep >= debt/lltv (+ buffer). lltv is WAD (e.g. 0.77e18).
            keep += (debtLeft * 1e18) / mp.lltv;
        }
        if (coll2 > keep) {
            uint256 freeAmt = uint256(coll2) - keep;
            morpho.withdrawCollateral(mp, freeAmt, king, king);
            emit RssFreedToKing(freeAmt, debtLeft, keep);
        } else {
            emit RssFreedToKing(0, debtLeft, coll2);
        }

        // Dust USDC on this contract → king (never re-deposit)
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(king, dust);
    }

    /// @notice After debt is dust-cleared: sweep any leftover yRSS liquidity to `landing` (ops treasury).
    /// @dev Call only after freeRssToKing(). Does not touch Morpho debt/collateral.
    function sweepYrssToLanding(address landing) external onlyOwner nonReentrant {
        require(landing != address(0), "landing");
        uint256 maxR = yrss.maxRedeem(king);
        if (maxR > 0) {
            yrss.redeem(maxR, landing, king);
        }
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(landing, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        usdc.approve(address(morpho), type(uint256).max);
        morpho.repay(mp, _repayAssets, 0, king, "");

        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) {
            uint256 need = assets - have;
            uint256 maxW = yrss.maxWithdraw(king);
            uint256 pull = maxW < need ? maxW : need;
            if (pull > 0) yrss.withdraw(pull, address(this), king);
            have = usdc.balanceOf(address(this));
        }
        if (have < assets) revert Short();
        usdc.approve(address(morpho), assets);
    }

    /// @dev Explicit hard-stop: this contract must never be used to re-lock RSS.
    function supplyCollateralForbidden() external pure {
        revert RecycleForbidden();
    }
}
