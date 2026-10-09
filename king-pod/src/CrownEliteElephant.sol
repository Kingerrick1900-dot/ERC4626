// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoEl {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function accrueInterest(MarketParams memory marketParams) external;

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes memory data
    ) external returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

interface IOracleEl {
    function price() external view returns (uint256);
    function setPrice(uint256 newPrice) external;
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @notice Elite Elephant — atomic self-del migrate: jammed Safe Gate → HOT-owned Elephant on SOV.
/// @dev Morpho flash (0%) · live-calibrated oracle self-del · reseat RSS + debt here · restore oracle.
///      RSS never sold. PAR seat deferred: parallel book has $0 idle; Kingdom SOV LP has no withdraw.
contract CrownEliteElephant is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    bytes32 public constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;
    address public constant LEGACY_GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;
    uint256 internal constant LIQUIDATION_CURSOR = 0.3e18;
    uint256 internal constant MAX_LIF = 1.15e18;

    IMorphoEl public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IOracleEl public immutable oracle;

    bool private _locking;

    event ElephantWalked(
        uint256 debtRepaidAssets, uint256 rssSeized, uint256 borrowedSov, uint256 priceRestored
    );

    error OnlyMorpho();
    error NoPos();
    error Short();
    error BadOracle();
    error FlashFail();
    error GateResidual();
    error BadLiqPrice();

    constructor(address morpho_, address usdc_, address rss_, address oracle_, address owner_) Ownable(owner_) {
        morpho = IMorphoEl(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        oracle = IOracleEl(oracle_);
        if (oracle.owner() != owner_) revert BadOracle();
    }

    /// @notice Fire the atomic migration. HOT/owner only. ZK doctrine: RSS stays collateral.
    function fire() external onlyOwner nonReentrant {
        (, uint128 borShares, uint128 coll) = morpho.position(SOV, LEGACY_GATE);
        if (borShares == 0 || coll == 0) revert NoPos();

        IMorphoEl.MarketParams memory sovMp = _params(SOV);
        morpho.accrueInterest(sovMp);
        (,, uint128 tba, uint128 tbs,,) = morpho.market(SOV);
        uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
        flashAmt += 5_000e6; // buffer for accrue during callback

        uint256 priceBefore = oracle.price();
        _locking = true;
        morpho.flashLoan(
            address(usdc), flashAmt, abi.encode(priceBefore, uint256(borShares), uint256(coll))
        );
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();

        (uint256 priceBefore, uint256 borShares, uint256 coll) =
            abi.decode(data, (uint256, uint256, uint256));

        IMorphoEl.MarketParams memory sovMp = _params(SOV);

        usdc.safeApprove(address(morpho), type(uint256).max);
        rss.safeApprove(address(morpho), type(uint256).max);

        // Accrue again so LIQ_PRICE band matches liquidate's internal accrue.
        morpho.accrueInterest(sovMp);
        (, uint128 liveBor, uint128 liveColl) = morpho.position(SOV, LEGACY_GATE);
        uint256 shares = uint256(liveBor);
        uint256 collAmt = uint256(liveColl);
        if (shares == 0) shares = borShares;
        if (collAmt == 0) collAmt = coll;

        (,, uint128 tba, uint128 tbs,,) = morpho.market(SOV);
        uint256 liqPrice = _liqPrice(shares, collAmt, uint256(tba), uint256(tbs), sovMp.lltv);
        if (liqPrice == 0) revert BadLiqPrice();

        // 1) Self-del: full share repay seizes all RSS at calibrated price (no bad debt).
        oracle.setPrice(liqPrice);
        (uint256 seized, uint256 repaidAssets) = morpho.liquidate(sovMp, LEGACY_GATE, 0, shares, "");
        if (seized == 0 || repaidAssets == 0) revert FlashFail();

        // Debt must be gone. Sub-wei RSS dust may remain on Gate (Morpho round-down); Safe-only withdraw.
        (, uint128 gateBor,) = morpho.position(SOV, LEGACY_GATE);
        if (gateBor != 0) revert GateResidual();

        uint256 rssBal = rss.balanceOf(address(this));
        if (rssBal == 0) revert FlashFail();

        // 2) Restore King oracle before opening the reseated book.
        oracle.setPrice(priceBefore);

        // 3) Reseat on SOV under this HOT-owned contract; borrow freed idle to repay flash.
        morpho.supplyCollateral(sovMp, rssBal, address(this), "");

        uint256 bal = usdc.balanceOf(address(this));
        uint256 need = assets > bal ? assets - bal : 0;
        uint256 borrowed;
        if (need > 0) {
            (borrowed,) = morpho.borrow(sovMp, need, 0, address(this), address(this));
        }

        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.safeApprove(address(morpho), assets);

        // 4) Return oracle to King HOT before flash ends.
        oracle.transferOwnership(owner);

        emit ElephantWalked(repaidAssets, seized, borrowed, priceBefore);
    }

    /// @dev Floor price where Morpho repaidShares→seizedAssets ≤ coll, and position is unhealthy.
    function _liqPrice(uint256 shares, uint256 collAmt, uint256 tba, uint256 tbs, uint256 lltv)
        internal
        pure
        returns (uint256 price)
    {
        uint256 lif = _lif(lltv);
        // Morpho: seized = toAssetsDown(shares).wMulDown(lif).mulDivDown(ORACLE, price)
        uint256 debtDown = _mulDivDown(shares, tba, tbs);
        uint256 num = _mulDivDown(debtDown, lif, WAD) * ORACLE_PRICE_SCALE;
        // smallest price with seized <= coll: ceil(num / collAmt) but Morpho uses floor div on seize,
        // so price = num / collAmt (floor) yields seized == coll when divides evenly, else seized < coll.
        // Underflow when seized > coll ⟺ price < ceil(num/coll). Use ceil:
        price = (num + collAmt - 1) / collAmt;

        // Ensure liquidatable: borrowed > coll * price / ORACLE * lltv / WAD
        uint256 debtUp = _mulDivUp(shares, tba, tbs);
        // maxBorrow at `price` = coll * price / ORACLE * lltv / WAD
        // need maxBorrow < debtUp ⇒ price < debtUp * ORACLE * WAD / (coll * lltv)
        uint256 pMax = (debtUp * ORACLE_PRICE_SCALE * WAD) / (collAmt * lltv);
        if (price >= pMax) {
            // nudge just below pMax; still must be >= ceil band
            if (pMax <= 1) revert BadLiqPrice();
            price = pMax - 1;
            // re-check seize fits
            uint256 seized = num / price; // mulDivDown equivalent for our num construction
            if (seized > collAmt) revert BadLiqPrice();
        }
    }

    function _lif(uint256 lltv) internal pure returns (uint256) {
        uint256 factor = WAD - _mulDivDown(LIQUIDATION_CURSOR, WAD - lltv, WAD);
        uint256 lif = (WAD * WAD) / factor; // wDivDown
        return lif < MAX_LIF ? lif : MAX_LIF;
    }

    function _mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y + d - 1) / d;
    }

    function _params(bytes32 id) internal view returns (IMorphoEl.MarketParams memory mp) {
        (address a, address b, address c, address d, uint256 e) = morpho.idToMarketParams(id);
        mp = IMorphoEl.MarketParams(a, b, c, d, e);
    }
}
