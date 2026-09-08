// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoVaultSolver {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

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

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface ICreditSink {
    function supply(uint256 amt) external;
}

/// @title CrownVaultSolver
/// @notice One contract = king USDC curator vault + exclusive Morpho solver (lender + borrower + bank).
/// @dev No flash. Seed USDC → supply eUSD book → post dual coll → borrow → keep 80% in book, peel 20% to Landing.
///      Dual coll = eUSD market + optional gUSD market. Peel never re-loops 100% (kills ghost $4.5M path).
contract CrownVaultSolver is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant BPS = 10_000;

    IMorphoVaultSolver public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    IERC20 public immutable gusd; // address(0) = eUSD-only
    address public immutable king;
    address public landing;
    address public credit; // optional CrownPrimeCredit — peel can land as lasting idle

    IMorphoVaultSolver.MarketParams public eusdMp;
    bytes32 public eusdMarketId;
    IMorphoVaultSolver.MarketParams public gusdMp;
    bytes32 public gusdMarketId;
    bool public gusdMarketSet;

    /// @notice Share of each borrow sent to Landing/credit (default 20%). Rest re-supplies the book.
    uint256 public peelBps = 2_000;
    /// @notice Soft LTV vs posted coll value (oracle $1 assumed for eUSD/gUSD), default 70%.
    uint256 public maxLtvBps = 7_000;
    /// @notice Freeze switch — willFromZero / willLoop blocked when false.
    bool public armed = true;

    /// @notice USDC parked in this vault (not yet supplied to Morpho), 6dp.
    uint256 public vaultUsdc;
    /// @notice Cumulative USDC this vault has supplied into Morpho books, 6dp.
    uint256 public bookSupplied;
    /// @notice Cumulative Morpho borrow pulled through this solver (king debt), 6dp.
    uint256 public totalBorrowed;
    /// @notice Cumulative peel to Landing/credit, 6dp.
    uint256 public totalPeeled;
    /// @notice Cumulative keep re-supplied to book, 6dp.
    uint256 public totalKept;

    uint256 public lastSeed;
    uint256 public lastBorrow;
    uint256 public lastPeel;
    uint256 public lastKeep;

    event LandingSet(address landing);
    event CreditSet(address credit);
    event EusdMarketSet(bytes32 indexed id, address oracle, uint256 lltv);
    event GusdMarketSet(bytes32 indexed id, address oracle, uint256 lltv);
    event PeelBpsSet(uint256 peelBps);
    event MaxLtvBpsSet(uint256 maxLtvBps);
    event Armed(bool on);
    event Deposited(uint256 amt, uint256 vaultUsdc);
    event BookSeeded(bytes32 indexed marketId, uint256 amt, uint256 bookSupplied);
    event CollPosted(address indexed token, uint256 amt);
    event WillFromZero(
        uint256 seed, uint256 borrowed, uint256 peeled, uint256 kept, uint256 landingBal, uint256 idleLeft
    );
    event WillLoop(uint256 borrowed, uint256 peeled, uint256 kept, uint256 idleLeft);
    event Repaid(uint256 amt);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error Ltv();
    error PeelMiss();
    error LandingMiss();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address eusd_,
        address gusd_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        require(morpho_ != address(0) && usdc_ != address(0) && eusd_ != address(0), "ZERO");
        require(king_ != address(0) && landing_ != address(0), "ZERO");
        morpho = IMorphoVaultSolver(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        gusd = IERC20(gusd_);
        king = king_;
        landing = landing_;
        usdc.safeApprove(morpho_, type(uint256).max);
        eusd.safeApprove(morpho_, type(uint256).max);
        if (gusd_ != address(0)) gusd.safeApprove(morpho_, type(uint256).max);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function setCredit(address credit_) external onlyOwner {
        credit = credit_;
        if (credit_ != address(0)) {
            usdc.safeApprove(credit_, 0);
            usdc.safeApprove(credit_, type(uint256).max);
        }
        emit CreditSet(credit_);
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setPeelBps(uint256 peelBps_) external onlyOwner {
        // 5%–50% — never full recycle (ghost path), never starve keep
        if (peelBps_ < 500 || peelBps_ > 5_000) revert BadAmt();
        peelBps = peelBps_;
        emit PeelBpsSet(peelBps_);
    }

    function setMaxLtvBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps > 8_600) revert BadAmt();
        maxLtvBps = bps;
        emit MaxLtvBpsSet(bps);
    }

    function setEusdMarket(address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (oracle == address(0) || irm == address(0) || lltv == 0 || id == bytes32(0)) revert BadAmt();
        eusdMp = IMorphoVaultSolver.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(eusd),
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
        eusdMarketId = id;
        emit EusdMarketSet(id, oracle, lltv);
    }

    function setGusdMarket(address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (address(gusd) == address(0)) revert NoMarket();
        if (oracle == address(0) || irm == address(0) || lltv == 0 || id == bytes32(0)) revert BadAmt();
        gusdMp = IMorphoVaultSolver.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(gusd),
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
        gusdMarketId = id;
        gusdMarketSet = true;
        emit GusdMarketSet(id, oracle, lltv);
    }

    function idleEusd() public view returns (uint256) {
        return _idle(eusdMarketId);
    }

    function idleGusd() public view returns (uint256) {
        if (!gusdMarketSet) return 0;
        return _idle(gusdMarketId);
    }

    function idleTotal() public view returns (uint256) {
        return idleEusd() + idleGusd();
    }

    /// @notice Park USDC in the vault (no Morpho yet). King funds the war chest.
    function deposit(uint256 amt) external onlyKing nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        vaultUsdc += amt;
        emit Deposited(amt, vaultUsdc);
    }

    /// @notice Push vault USDC into the eUSD Morpho book (create owned idle). No borrow.
    function seedBook(uint256 amt) external onlyKing nonReentrant returns (uint256) {
        if (eusdMarketId == bytes32(0)) revert NoMarket();
        if (amt == 0 || amt > vaultUsdc) revert BadAmt();
        vaultUsdc -= amt;
        morpho.supply(eusdMp, amt, 0, address(this), "");
        bookSupplied += amt;
        emit BookSeeded(eusdMarketId, amt, bookSupplied);
        return amt;
    }

    /// @notice Post eUSD as Morpho collateral on behalf of king (capacity, not dollars).
    function postEusd(uint256 amt) external onlyKing nonReentrant {
        if (eusdMarketId == bytes32(0)) revert NoMarket();
        if (amt == 0) revert BadAmt();
        eusd.safeTransferFrom(msg.sender, address(this), amt);
        morpho.supplyCollateral(eusdMp, amt, king, "");
        emit CollPosted(address(eusd), amt);
    }

    /// @notice Post gUSD as Morpho collateral on behalf of king (dual-coll rail).
    function postGusd(uint256 amt) external onlyKing nonReentrant {
        if (!gusdMarketSet) revert NoMarket();
        if (amt == 0) revert BadAmt();
        gusd.safeTransferFrom(msg.sender, address(this), amt);
        morpho.supplyCollateral(gusdMp, amt, king, "");
        emit CollPosted(address(gusd), amt);
    }

    /// @notice Decree: seed → supply book → post dual coll → borrow → keep 80% / peel 20%.
    /// @param seedUsdc USDC pulled from king into vault then supplied to eUSD book (0 = use vaultUsdc).
    /// @param eusdColl eUSD to post as Morpho coll (0 = skip).
    /// @param gusdColl gUSD to post as Morpho coll (0 = skip).
    /// @param borrowAsk Max USDC to borrow across books (0 = all idle after seed).
    function willFromZero(uint256 seedUsdc, uint256 eusdColl, uint256 gusdColl, uint256 borrowAsk)
        external
        onlyKing
        nonReentrant
        returns (uint256 peeled, uint256 kept)
    {
        if (!armed) revert NotArmed();
        if (eusdMarketId == bytes32(0)) revert NoMarket();

        // 1) Fund vault
        if (seedUsdc > 0) {
            usdc.safeTransferFrom(msg.sender, address(this), seedUsdc);
            vaultUsdc += seedUsdc;
        }
        uint256 toBook = seedUsdc > 0 ? seedUsdc : vaultUsdc;
        if (toBook == 0 && idleTotal() == 0) revert BadAmt();

        // 2) Own-seed the eUSD book (create idle we control)
        if (toBook > 0) {
            if (toBook > vaultUsdc) toBook = vaultUsdc;
            vaultUsdc -= toBook;
            morpho.supply(eusdMp, toBook, 0, address(this), "");
            bookSupplied += toBook;
            emit BookSeeded(eusdMarketId, toBook, bookSupplied);
        }

        // 3) Dual collateral → capacity
        if (eusdColl > 0) {
            eusd.safeTransferFrom(msg.sender, address(this), eusdColl);
            morpho.supplyCollateral(eusdMp, eusdColl, king, "");
            emit CollPosted(address(eusd), eusdColl);
        }
        if (gusdColl > 0) {
            if (!gusdMarketSet) revert NoMarket();
            gusd.safeTransferFrom(msg.sender, address(this), gusdColl);
            morpho.supplyCollateral(gusdMp, gusdColl, king, "");
            emit CollPosted(address(gusd), gusdColl);
        }

        _ltvGuard(eusdColl, gusdColl, borrowAsk == 0 ? idleTotal() : borrowAsk);

        // 4) Borrow + split
        (peeled, kept) = _borrowSplit(borrowAsk);

        lastSeed = toBook;
        emit WillFromZero(toBook, lastBorrow, peeled, kept, usdc.balanceOf(landing), idleTotal());
    }

    /// @notice Next Fibonacci slice: borrow existing owned idle, keep 80% / peel 20%. No new seed required.
    function willLoop(uint256 borrowAsk) external onlyKing nonReentrant returns (uint256 peeled, uint256 kept) {
        if (!armed) revert NotArmed();
        if (eusdMarketId == bytes32(0)) revert NoMarket();
        if (idleTotal() == 0) revert IdleMiss();
        (peeled, kept) = _borrowSplit(borrowAsk);
        emit WillLoop(lastBorrow, peeled, kept, idleTotal());
    }

    /// @notice King/ops repay Morpho debt from wallet USDC (self-liq rail).
    function repayEusd(uint256 amt) external onlyKing nonReentrant {
        if (eusdMarketId == bytes32(0)) revert NoMarket();
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        morpho.repay(eusdMp, amt, 0, king, "");
        if (totalBorrowed >= amt) totalBorrowed -= amt;
        else totalBorrowed = 0;
        emit Repaid(amt);
    }

    function book()
        external
        view
        returns (
            bool isArmed,
            uint256 vault,
            uint256 idle,
            uint256 supplied,
            uint256 borrowed,
            uint256 peeled,
            uint256 kept,
            uint256 landingUsdc
        )
    {
        isArmed = armed;
        vault = vaultUsdc;
        idle = idleTotal();
        supplied = bookSupplied;
        borrowed = totalBorrowed;
        peeled = totalPeeled;
        kept = totalKept;
        landingUsdc = usdc.balanceOf(landing);
    }

    // ─── internals ───────────────────────────────────────────────────────────

    function _idle(bytes32 id) internal view returns (uint256) {
        if (id == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(id);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @dev Soft LTV: borrowAsk (6dp) vs coll (18dp) at $1 → borrow * 1e12 <= coll * maxLtvBps / BPS.
    function _ltvGuard(uint256 eusdColl, uint256 gusdColl, uint256 borrowAsk) internal view {
        if (borrowAsk == 0) return;
        uint256 coll = eusdColl + gusdColl;
        if (coll == 0) return; // relying on already-posted Morpho coll
        if (borrowAsk * 1e12 > (coll * maxLtvBps) / BPS) revert Ltv();
    }

    function _borrowSplit(uint256 borrowAsk) internal returns (uint256 peeled, uint256 kept) {
        uint256 eIdle = idleEusd();
        uint256 gIdle = idleGusd();
        uint256 idle = eIdle + gIdle;
        if (idle == 0) revert IdleMiss();

        uint256 want = borrowAsk == 0 || borrowAsk > idle ? idle : borrowAsk;
        uint256 got;

        // Pull from eUSD book first (primary owned rail)
        uint256 fromE = want <= eIdle ? want : eIdle;
        if (fromE > 0) {
            morpho.borrow(eusdMp, fromE, 0, king, address(this));
            got += fromE;
        }
        // Then gUSD book if dual market live
        uint256 remain = want - got;
        if (remain > 0 && gIdle > 0 && gusdMarketSet) {
            uint256 fromG = remain <= gIdle ? remain : gIdle;
            morpho.borrow(gusdMp, fromG, 0, king, address(this));
            got += fromG;
        }
        if (got == 0) revert IdleMiss();

        peeled = (got * peelBps) / BPS;
        kept = got - peeled;
        if (peeled == 0) revert PeelMiss();

        // KEEP → re-supply eUSD book (fat books, owned depth)
        if (kept > 0) {
            morpho.supply(eusdMp, kept, 0, address(this), "");
            bookSupplied += kept;
            totalKept += kept;
        }

        // PEEL → Landing cash (or credit idle for draw rail)
        _peelOut(peeled);

        totalBorrowed += got;
        totalPeeled += peeled;
        lastBorrow = got;
        lastPeel = peeled;
        lastKeep = kept;
    }

    function _peelOut(uint256 amt) internal {
        if (amt == 0) return;
        if (credit != address(0)) {
            ICreditSink(credit).supply(amt);
        } else {
            uint256 before = usdc.balanceOf(landing);
            usdc.safeTransfer(landing, amt);
            if (usdc.balanceOf(landing) < before + amt) revert LandingMiss();
        }
    }
}
