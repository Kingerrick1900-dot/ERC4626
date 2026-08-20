// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @title CrownRss1200Signal
/// @notice Re-claim the RSS/$1200 matched book (signal / PoD). Not an idle/payroll gun.
///
/// Seed: flash USDC → supply + post RSS coll on HOT → borrow same USDC → repay flash.
/// Unwind / self-del / self-liq: flash → repay → RSS back to HOT → withdraw supply → repay flash.
///
/// Position lives on HOT. This chassis stays Morpho-authorized so unwind is one call.
/// Do not post the whole RSS stack — coll is capped; leftover RSS stays liquid on HOT.

interface IMorphoSignal {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IOracleSignal {
    function price() external view returns (uint256);
}

contract CrownRss1200Signal is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint8 internal constant MODE_SEED = 1;
    uint8 internal constant MODE_UNWIND = 2;

    /// @dev $200M matched book — same signal as live seed tx 0xbe63e15e…
    uint256 public constant ASK_USDC = 200_000_000e6;
    /// @dev 250k RSS @ $1200 = $300M coll vs $200M debt → HF 1.50 (LLTV 1.298). Old fire used 220k (razor).
    uint256 public constant COLL_RSS = 250_000 ether;
    /// @dev Never lock the stack. After post, HOT must still hold this much free RSS.
    uint256 public constant MIN_FREE_RSS = 1_000_000 ether;
    /// @dev Hard cap so env cannot dump inventory into Morpho.
    uint256 public constant MAX_COLL_RSS = 500_000 ether;
    /// @dev HF 1.50 in 1e18 (collValue / debt).
    uint256 public constant MIN_HF_WAD = 1.5e18;
    /// @dev Matched book: king is both sides — interest washes. No USDC buffer required.
    ///      Flash size = exact debt assets (ceil). Optional 1-wei cover via _cover if hot has dust.

    IMorphoSignal public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoSignal.MarketParams public mp;

    uint256 public lastAsk;
    uint256 public lastColl;
    bool public lastClosed;
    bool private _locking;

    event SignalSeeded(uint256 ask, uint256 collRss, uint256 hfWad, uint256 rssFreeAfter);
    event SignalUnwound(uint256 rssBack, uint256 supplyWithdrawn);

    error OnlyMorpho();
    error BadAmt();
    error Headroom();
    error Hf();
    error Short();
    error Busy();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_
    ) Ownable(king_) {
        morpho = IMorphoSignal(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoSignal.MarketParams(usdc_, rss_, oracle_, irm_, lltv_);
    }

    function hfWad(uint256 collRss, uint256 debtUsdc) public view returns (uint256) {
        if (debtUsdc == 0) return type(uint256).max;
        uint256 px = IOracleSignal(mp.oracle).price();
        uint256 collValue = (collRss * px) / 1e36;
        return (collValue * 1e18) / debtUsdc;
    }

    /// @notice Matched $200M book on HOT. `ask=0` / `collRss=0` → defaults (200M / 250k).
    function seed(uint256 ask, uint256 collRss) external onlyOwner nonReentrant {
        if (ask == 0) ask = ASK_USDC;
        if (collRss == 0) collRss = COLL_RSS;
        if (ask != ASK_USDC) revert BadAmt();
        if (collRss > MAX_COLL_RSS || collRss < COLL_RSS) revert Headroom();
        if (hfWad(collRss, ask) < MIN_HF_WAD) revert Hf();

        (, uint128 borShares, uint128 liveColl) = morpho.position(marketId, king);
        if (borShares != 0 || liveColl != 0) revert Busy();

        uint256 free = rss.balanceOf(king);
        if (free < collRss + MIN_FREE_RSS) revert Headroom();

        rss.safeTransferFrom(king, address(this), collRss);
        lastAsk = ask;
        lastColl = collRss;
        lastClosed = false;

        _locking = true;
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_SEED, ask, collRss, uint256(0), uint256(0), uint256(0)));
        _locking = false;

        uint256 leftU = usdc.balanceOf(address(this));
        if (leftU > 0) usdc.safeTransfer(king, leftU);
        uint256 leftR = rss.balanceOf(address(this));
        if (leftR > 0) rss.safeTransfer(king, leftR);

        emit SignalSeeded(ask, collRss, hfWad(collRss, ask), rss.balanceOf(king));
    }

    /// @notice Self-del / self-liq. RSS returns to HOT. Book goes to zero.
    function unwind() public onlyOwner nonReentrant {
        _unwind();
    }

    function selfDel() external onlyOwner nonReentrant {
        _unwind();
    }

    function selfLiq() external onlyOwner nonReentrant {
        _unwind();
    }

    function _unwind() internal {
        if (_locking) revert Busy();
        morpho.accrueInterest(mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        if (borShares == 0 && coll == 0 && supShares == 0) {
            lastClosed = true;
            return;
        }

        if (borShares > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            // Exact debt ceil — no $2k pad. Matched supply interest offsets borrow interest.
            uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
            _locking = true;
            morpho.flashLoan(
                address(usdc),
                flashAmt,
                abi.encode(MODE_UNWIND, flashAmt, uint256(coll), supShares, uint256(borShares), uint256(coll))
            );
            _locking = false;
        } else {
            if (coll > 0) morpho.withdrawCollateral(mp, coll, king, king);
            if (supShares > 0) morpho.withdraw(mp, 0, supShares, king, king);
        }

        uint256 u = usdc.balanceOf(address(this));
        if (u > 0) usdc.safeTransfer(king, u);
        uint256 r = rss.balanceOf(address(this));
        if (r > 0) rss.safeTransfer(king, r);

        lastClosed = true;
        emit SignalUnwound(uint256(coll), supShares);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();
        (uint8 mode, uint256 ask, uint256 collRss, uint256 supShares, uint256 borShares, uint256 coll) =
            abi.decode(data, (uint8, uint256, uint256, uint256, uint256, uint256));
        if (assets != ask) revert BadAmt();

        usdc.safeApprove(address(morpho), type(uint256).max);

        if (mode == MODE_SEED) {
            rss.safeApprove(address(morpho), collRss);
            morpho.supply(mp, ask, 0, king, "");
            morpho.supplyCollateral(mp, collRss, king, "");
            morpho.borrow(mp, ask, 0, king, address(this));
            _cover(assets);
        } else if (mode == MODE_UNWIND) {
            if (borShares > 0) morpho.repay(mp, 0, borShares, king, "");
            if (coll > 0) morpho.withdrawCollateral(mp, coll, king, king);
            if (supShares > 0) morpho.withdraw(mp, 0, supShares, king, address(this));
            _cover(assets);
        } else {
            revert BadAmt();
        }

        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.safeApprove(address(morpho), assets);
    }

    function _cover(uint256 assets) internal {
        uint256 have = usdc.balanceOf(address(this));
        if (have >= assets) return;
        uint256 need = assets - have;
        usdc.safeTransferFrom(king, address(this), need);
    }
}
