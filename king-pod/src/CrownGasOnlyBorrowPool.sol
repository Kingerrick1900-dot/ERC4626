// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoPool {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IMorphoFlashCb {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoPool {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IOraclePool {
    function price() external view returns (uint256);
}

interface IFlashBoundPack {
    function fireLive(uint256 amount) external returns (bool proven, uint256 landingDelta);
    function subject() external view returns (address);
}

interface IBoundGatePack {
    function isProven(address) external view returns (bool);
    function minThreshold() external view returns (uint256);
    function attestations(address) external view returns (uint256, uint256, bool);
}

interface IPublicAllocatorPool {
    struct Withdrawal {
        bytes32 marketId;
        uint128 amount;
    }

    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, bytes32 supplyMarketId) external;
}

/// @title CrownGasOnlyBorrowPool
/// @notice Top→bottom gas-only borrowable-pool engine (survivor playbook stack).
///
/// Plays encoded (all used by live protocols):
///   • Peapods — demand/util already LIVE (keep loud)
///   • Kamino/SelfSeed — flash USDC → yRSS seed → borrow vs RSS coll → repay flash
///   • Morpho PA — reallocate vault depth into RSS/$1200 when present
///   • Lazy Summer — donate RSS into NAV ledger (oracle-priced) for depth signal
///   • Pack — refresh $1M flash-bound ticket (LIVE gate/flash)
///
/// Physics: gasPark creates yRSS war-chest + Morpho debt (matched). Lasting *idle*
/// for borrowToLanding appears when unmatched USDC sits on RSS/$1200 (PA in, LPs,
/// or donation-funded supply). No pocket USDC required for park — Morpho flash is the leg.
contract CrownGasOnlyBorrowPool is Ownable, ReentrancyGuard, IMorphoFlashCb {
    using SafeTransfer for IERC20;

    uint256 internal constant ORACLE_SCALE = 1e36;

    IMorphoPool public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IMetaMorphoPool public immutable yrss;
    IOraclePool public immutable oracle;
    IFlashBoundPack public immutable flashPack;
    IBoundGatePack public immutable gate;
    IPublicAllocatorPool public immutable pa;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoPool.MarketParams public mp;

    uint256 public maxLtvBps = 7000; // soft 70% vs $1200 oracle for new coll
    uint256 public navRss; // Lazy Summer donated RSS (18dp)
    uint256 public lastParkUsdc;
    uint256 public lastParkShares;
    uint256 public lastBorrowToLanding;
    bool private _locking;

    event PackRefreshed(bool proven, uint256 minThreshold);
    event GasParked(uint256 rssColl, uint256 usdcParked, uint256 yrssShares, uint256 yrssTotalAssets);
    event RssDonated(uint256 rssAmt, uint256 navUsd6);
    event Reallocated(bytes32 indexed fromMarket, uint256 amount, bytes32 toMarket);
    event BorrowedToLanding(uint256 usdcOut, uint256 landingBal);
    event MaxLtv(uint256 bps);

    error OnlyMorpho();
    error OnlyKing();
    error BadAmt();
    error Ltv();
    error IdleMiss();
    error PackMiss();
    error LandingMiss();
    error NoAuth();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert OnlyKing();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address yrss_,
        address oracle_,
        address flashPack_,
        address gate_,
        address pa_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoPool(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IMetaMorphoPool(yrss_);
        oracle = IOraclePool(oracle_);
        flashPack = IFlashBoundPack(flashPack_);
        gate = IBoundGatePack(gate_);
        pa = IPublicAllocatorPool(pa_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoPool.MarketParams(usdc_, rss_, oracle_, irm_, lltv_);
        require(flashPack.subject() == king_, "PACK_SUBJECT");
    }

    function setMaxLtvBps(uint256 bps) external onlyOwner {
        require(bps > 0 && bps <= 7700, "BPS");
        maxLtvBps = bps;
        emit MaxLtv(bps);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function packReady() public view returns (bool) {
        if (!gate.isProven(king)) return false;
        (uint256 v,, bool valid) = gate.attestations(king);
        return valid && v >= gate.minThreshold();
    }

    /// @notice NAV = donated RSS * oracle (USDC 6dp) — Lazy Summer depth signal.
    function navUsdc6() public view returns (uint256) {
        if (navRss == 0) return 0;
        return navRss * oracle.price() / ORACLE_SCALE;
    }

    function book()
        external
        view
        returns (
            bool proven,
            uint256 idleUsdc,
            uint256 yrssAssets,
            uint256 nav,
            uint256 landingUsdc
        )
    {
        proven = packReady();
        idleUsdc = idle();
        yrssAssets = yrss.totalAssets();
        nav = navUsdc6();
        landingUsdc = usdc.balanceOf(landing);
    }

    /// @notice Layer Z — refresh $1M flash-bound ticket (net pocket USDC = 0).
    function refreshPack(uint256 amount) external onlyKing nonReentrant returns (bool proven) {
        if (amount == 0) amount = gate.minThreshold();
        uint256 d;
        (proven, d) = flashPack.fireLive(amount);
        if (!proven) revert PackMiss();
        emit PackRefreshed(proven, amount);
    }

    /// @notice Lazy Summer — donate free RSS into NAV ledger (loan, don't sell).
    function donateRss(uint256 rssAmt) external onlyKing nonReentrant {
        if (rssAmt == 0) rssAmt = rss.balanceOf(king);
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(king, address(this), rssAmt);
        navRss += rssAmt;
        emit RssDonated(rssAmt, navUsdc6());
    }

    /// @notice Kamino/SelfSeed gas park: flash → yRSS → borrow vs RSS → repay.
    /// @dev Min $1M. Caps at yRSS market cap (~$14M). Creates war-chest shares; Morpho debt matched.
    function gasPark(uint256 rssColl, uint256 usdcAmt) external onlyKing nonReentrant {
        if (usdcAmt == 0) usdcAmt = 1_000_000e6;
        if (usdcAmt < 1_000_000e6) revert BadAmt();
        if (rssColl == 0) rssColl = rss.balanceOf(king);
        // borrowUsdc (6dp) <= rssColl * maxLtvBps/10000 * oracle/1e36
        uint256 maxBorrow = rssColl * oracle.price() / ORACLE_SCALE * maxLtvBps / 10_000;
        if (usdcAmt > maxBorrow) revert Ltv();

        rss.safeTransferFrom(king, address(this), rssColl);
        rss.approve(address(morpho), rssColl);
        morpho.supplyCollateral(mp, rssColl, king, "");

        _locking = true;
        morpho.flashLoan(address(usdc), usdcAmt, abi.encode(uint8(1), rssColl, usdcAmt));
        _locking = false;
        emit GasParked(rssColl, lastParkUsdc, lastParkShares, yrss.totalAssets());
    }

    /// @notice Morpho PA — pull depth from other yRSS markets into RSS/$1200 (borrowable idle).
    function reallocateIn(bytes32 fromMarket, uint128 amount) external onlyKing nonReentrant {
        if (amount == 0) revert BadAmt();
        IPublicAllocatorPool.Withdrawal[] memory w = new IPublicAllocatorPool.Withdrawal[](1);
        w[0] = IPublicAllocatorPool.Withdrawal({marketId: fromMarket, amount: amount});
        pa.reallocateTo(address(yrss), w, marketId);
        emit Reallocated(fromMarket, amount, marketId);
    }

    /// @notice Borrow unmatched Morpho idle → Landing. Size = pool depth (no $700k ceiling).
    /// @notice Borrow unmatched Morpho idle → Landing. Anyone. Size = available idle.
    function borrowToLanding(uint256 usdcOut) external nonReentrant returns (uint256) {
        return _borrowToLanding(usdcOut);
    }

    /// @notice Permissionless: drain all available idle to Landing.
    function poke() external nonReentrant returns (uint256) {
        uint256 avail = idle();
        if (avail == 0) revert IdleMiss();
        return _borrowToLanding(avail);
    }

    function _borrowToLanding(uint256 usdcOut) internal returns (uint256) {
        if (usdcOut == 0) revert BadAmt();
        morpho.accrueInterest(mp);
        if (idle() < usdcOut) revert IdleMiss();
        uint256 before = usdc.balanceOf(landing);
        morpho.borrow(mp, usdcOut, 0, king, landing);
        uint256 delta = usdc.balanceOf(landing) - before;
        if (delta < usdcOut) revert LandingMiss();
        lastBorrowToLanding = delta;
        emit BorrowedToLanding(delta, usdc.balanceOf(landing));
        return delta;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint8 mode,, uint256 usdcAmt) = abi.decode(data, (uint8, uint256, uint256));
        if (mode != 1 || assets != usdcAmt) revert BadAmt();

        // Seed yRSS (queue[0] = RSS/$1200) — shares to king
        usdc.approve(address(yrss), assets);
        uint256 shares = yrss.deposit(assets, king);

        // Idle must now cover flash — borrow onBehalf king to this contract
        if (idle() < assets) revert NoAuth();
        morpho.borrow(mp, assets, 0, king, address(this));
        usdc.approve(address(morpho), assets);

        lastParkUsdc = assets;
        lastParkShares = shares;
    }
}
