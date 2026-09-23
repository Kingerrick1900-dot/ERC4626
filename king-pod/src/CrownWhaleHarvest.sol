// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoH {
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

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IOracleH {
    function price() external view returns (uint256);
}

/// @title CrownWhaleHarvest
/// @notice Universal Morpho vacuum: any registered loan book (USDC/DAI/USDbC/EURC/…) vs
///         kingdom collateral (eUSD, cbBTC, WETH, RSS, …). Drains idle → Landing.
/// @dev Does not mint Circle. Engineers by borrowing foreign idle against posted coll.
///      Vacuum: re-call when any book refills. Freeze-gated via `armed`.
contract CrownWhaleHarvest is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant ORACLE_SCALE = 1e36;
    uint256 public constant WAD = 1e18;
    uint256 public constant HAIRCUT_BPS = 9_500;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_MARKETS = 32;

    IMorphoH public immutable morpho;
    address public immutable king;
    address public landing;

    bool public armed = true;

    bytes32[] public marketIds;
    mapping(bytes32 => IMorphoH.MarketParams) public markets;
    mapping(bytes32 => bool) public isMarket;
    mapping(bytes32 => uint256) public totalHarvested;

    uint256 public lastHarvestAmt;
    bytes32 public lastHarvestId;

    event Armed(bool on);
    event LandingSet(address landing);
    event MarketAdded(bytes32 id, address loan, address coll, uint256 lltv);
    event MarketRemoved(bytes32 id);
    event Harvested(bytes32 id, address loan, uint256 borrowed, uint256 idleLeft, address to);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error UnknownMarket();
    error IdleMiss();
    error DupMarket();
    error TooMany();
    error BadParams();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(address morpho_, address king_, address landing_, address owner_) Ownable(owner_) {
        if (morpho_ == address(0) || king_ == address(0) || landing_ == address(0)) revert BadAmt();
        morpho = IMorphoH(morpho_);
        king = king_;
        landing = landing_;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function marketCount() external view returns (uint256) {
        return marketIds.length;
    }

    /// @notice Register a Morpho Blue market by id (params read on-chain).
    function addMarket(bytes32 id) external onlyOwner {
        if (isMarket[id]) revert DupMarket();
        if (marketIds.length >= MAX_MARKETS) revert TooMany();
        (address loan, address coll, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(id);
        if (loan == address(0) || oracle == address(0) || lltv == 0) revert BadParams();
        markets[id] = IMorphoH.MarketParams(loan, coll, oracle, irm, lltv);
        isMarket[id] = true;
        marketIds.push(id);
        IERC20(loan).safeApprove(address(morpho), type(uint256).max);
        if (coll != address(0)) IERC20(coll).safeApprove(address(morpho), type(uint256).max);
        emit MarketAdded(id, loan, coll, lltv);
    }

    function removeMarket(bytes32 id) external onlyOwner {
        if (!isMarket[id]) revert UnknownMarket();
        isMarket[id] = false;
        delete markets[id];
        uint256 n = marketIds.length;
        for (uint256 i; i < n; ++i) {
            if (marketIds[i] == id) {
                marketIds[i] = marketIds[n - 1];
                marketIds.pop();
                break;
            }
        }
        emit MarketRemoved(id);
    }

    function idleOf(bytes32 id) public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(id);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Max loan assets borrowable vs `collAmt` at haircut LLTV.
    function maxBorrow(bytes32 id, uint256 collAmt) public view returns (uint256) {
        IMorphoH.MarketParams memory mp = markets[id];
        if (mp.lltv == 0 || collAmt == 0) return 0;
        uint256 px = IOracleH(mp.oracle).price();
        if (px == 0) return 0;
        uint256 value = collAmt * px / ORACLE_SCALE; // loan-token precision
        return value * mp.lltv / WAD * HAIRCUT_BPS / BPS;
    }

    /// @notice Coll needed to borrow `loanAmt` at haircut LLTV (ceil).
    function collForLoan(bytes32 id, uint256 loanAmt) public view returns (uint256) {
        IMorphoH.MarketParams memory mp = markets[id];
        if (mp.lltv == 0 || loanAmt == 0) return 0;
        uint256 px = IOracleH(mp.oracle).price();
        if (px == 0) return 0;
        uint256 num = loanAmt * ORACLE_SCALE * WAD * BPS;
        uint256 den = px * mp.lltv * HAIRCUT_BPS;
        return (num + den - 1) / den;
    }

    /// @notice Drain up to `maxLoan` (0 = all idle) from one book vs collateral pulled from king.
    /// @param collAmt 0 = auto-size for target borrow from king's wallet balance.
    function harvest(bytes32 id, uint256 collAmt, uint256 maxLoan)
        external
        onlyKing
        nonReentrant
        returns (uint256 borrowed)
    {
        if (!armed) revert NotArmed();
        if (!isMarket[id]) revert UnknownMarket();

        IMorphoH.MarketParams memory mp = markets[id];
        uint256 idle = idleOf(id);
        if (idle == 0) revert IdleMiss();

        uint256 target = maxLoan == 0 ? idle : (maxLoan < idle ? maxLoan : idle);

        if (collAmt == 0) {
            collAmt = collForLoan(id, target);
            uint256 bal = IERC20(mp.collateralToken).balanceOf(king);
            if (collAmt > bal) collAmt = bal;
        }
        if (collAmt == 0) revert BadAmt();

        IERC20(mp.collateralToken).safeTransferFrom(king, address(this), collAmt);
        morpho.supplyCollateral(mp, collAmt, address(this), "");

        uint256 room = maxBorrow(id, collAmt);
        borrowed = target < room ? target : room;
        if (borrowed == 0) revert IdleMiss();

        morpho.borrow(mp, borrowed, 0, address(this), landing);

        totalHarvested[id] += borrowed;
        lastHarvestAmt = borrowed;
        lastHarvestId = id;
        emit Harvested(id, mp.loanToken, borrowed, idleOf(id), landing);
    }

    /// @notice Vacuum every registered market with idle > 0 (best-effort; skips empties).
    function vacuumAll() external onlyKing nonReentrant returns (uint256 total) {
        if (!armed) revert NotArmed();
        uint256 n = marketIds.length;
        for (uint256 i; i < n; ++i) {
            bytes32 id = marketIds[i];
            if (!isMarket[id]) continue;
            uint256 idle = idleOf(id);
            if (idle == 0) continue;

            IMorphoH.MarketParams memory mp = markets[id];
            uint256 need = collForLoan(id, idle);
            uint256 bal = IERC20(mp.collateralToken).balanceOf(king);
            if (bal == 0) continue;
            if (need > bal) need = bal;
            if (need == 0) continue;

            IERC20(mp.collateralToken).safeTransferFrom(king, address(this), need);
            morpho.supplyCollateral(mp, need, address(this), "");

            uint256 room = maxBorrow(id, need);
            uint256 borrowed = idle < room ? idle : room;
            if (borrowed == 0) continue;

            morpho.borrow(mp, borrowed, 0, address(this), landing);
            totalHarvested[id] += borrowed;
            total += borrowed;
            lastHarvestAmt = borrowed;
            lastHarvestId = id;
            emit Harvested(id, mp.loanToken, borrowed, idleOf(id), landing);
        }
    }

    /// @notice Repay loan on a market (king funds). Frees coll for withdraw.
    function repay(bytes32 id, uint256 assets) external onlyKing nonReentrant {
        if (!isMarket[id]) revert UnknownMarket();
        IMorphoH.MarketParams memory mp = markets[id];
        IERC20(mp.loanToken).safeTransferFrom(king, address(this), assets);
        morpho.repay(mp, assets, 0, address(this), "");
    }

    function withdrawColl(bytes32 id, uint256 assets) external onlyKing nonReentrant {
        if (!isMarket[id]) revert UnknownMarket();
        IMorphoH.MarketParams memory mp = markets[id];
        morpho.withdrawCollateral(mp, assets, address(this), king);
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
