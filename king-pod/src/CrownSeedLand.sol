// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownSeedLand
/// @notice Engineer idle, borrow MORE than flash, Landing keeps the surplus.
///
/// Conservation (empty book):
///   flash F
///   + buffer `want` USDC from king
///   → unmatched supply(F + want)     // idle = F+want
///   → supplyCollateral(free RSS)
///   → borrow(F + want)               // borrow > flash
///   → want → Landing ; F → repay flash
///
/// Buffer becomes king's Morpho supply (not spent). HARD LAW: Landing Δ == want.

interface IERC20SL {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoSL {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function accrueInterest(MarketParams memory) external;
}

interface IOracleSL {
    function price() external view returns (uint256);
}

contract CrownSeedLand {
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;

    IMorphoSL public immutable morpho;
    IERC20SL public immutable usdc;
    IERC20SL public immutable rss;
    IOracleSL public immutable oracle;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoSL.MarketParams public mp;

    uint256 public lastFlash;
    uint256 public lastWant;
    uint256 public lastRssColl;
    uint256 public lastPeakIdle;
    uint256 public lastBorrowed;
    uint256 public lastLandingCredit;

    event SeedLand(
        uint256 flash, uint256 want, uint256 rssColl, uint256 peakIdle, uint256 borrowed, uint256 landingCredit
    );

    error KingOnly();
    error IdleMiss();
    error CloseFail();
    error LandingMiss();
    error Ltv();
    error BadAmt();
    error BufferMiss();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        address landing_,
        bytes32 marketId_
    ) {
        morpho = IMorphoSL(morpho_);
        usdc = IERC20SL(usdc_);
        rss = IERC20SL(rss_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        (address loan, address coll, address oracle_, address irm, uint256 lltv) =
            IMorphoSL(morpho_).idToMarketParams(marketId_);
        require(loan == usdc_ && coll == rss_, "MKT");
        oracle = IOracleSL(oracle_);
        mp = IMorphoSL.MarketParams(loan, coll, oracle_, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Seed book + land `want`. Flash = `closeFlash` (0 → want). Borrow = flash+want.
    /// @dev Pulls `want` USDC buffer from king (becomes Morpho supply) + `rssColl` free RSS.
    function seedLand(uint256 rssColl, uint256 want, uint256 closeFlash) external {
        if (msg.sender != king) revert KingOnly();
        if (want == 0 || rssColl == 0) revert BadAmt();
        if (closeFlash == 0) closeFlash = want;

        uint256 borrowTotal = closeFlash + want;
        _requireLtv(rssColl, borrowTotal);

        require(rss.transferFrom(king, address(this), rssColl), "RSS");
        // Buffer = want — engineers idle above flash so borrow can exceed flash
        if (usdc.balanceOf(address(this)) < want) {
            require(usdc.transferFrom(king, address(this), want), "BUF");
        }
        if (usdc.balanceOf(address(this)) < want) revert BufferMiss();

        uint256 landBefore = usdc.balanceOf(landing);
        morpho.flashLoan(address(usdc), closeFlash, abi.encode(rssColl, want, closeFlash, landBefore));

        if (usdc.balanceOf(landing) < landBefore + want) revert LandingMiss();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint256 rssColl, uint256 want, uint256 closeFlash,) =
            abi.decode(data, (uint256, uint256, uint256, uint256));
        require(assets == closeFlash, "AMT");

        uint256 borrowTotal = closeFlash + want;
        morpho.accrueInterest(mp);

        // 1) Engineer idle = flash + buffer (borrow can exceed flash)
        uint256 supplyAmt = closeFlash + want;
        usdc.approve(address(morpho), supplyAmt);
        morpho.supply(mp, supplyAmt, 0, king, "");

        uint256 peak = idle();
        if (peak < borrowTotal) revert IdleMiss();

        // 2) Free RSS equity
        rss.approve(address(morpho), rssColl);
        morpho.supplyCollateral(mp, rssColl, king, "");

        // 3) Borrow MORE than flash; surplus → Landing
        morpho.borrow(mp, borrowTotal, 0, king, address(this));

        uint256 onRouter = usdc.balanceOf(address(this));
        if (onRouter < borrowTotal) revert CloseFail();
        require(usdc.transfer(landing, want), "LAND");
        if (usdc.balanceOf(address(this)) < closeFlash) revert CloseFail();

        lastFlash = closeFlash;
        lastWant = want;
        lastRssColl = rssColl;
        lastPeakIdle = peak;
        lastBorrowed = borrowTotal;
        lastLandingCredit = want;

        usdc.approve(address(morpho), closeFlash);
        emit SeedLand(closeFlash, want, rssColl, peak, borrowTotal, want);
    }

    function _requireLtv(uint256 rssColl, uint256 borrowUsdc) internal view {
        uint256 collValue = rssColl * oracle.price() / ORACLE_PRICE_SCALE;
        uint256 maxBorrow = collValue * mp.lltv / 1e18;
        if (borrowUsdc > maxBorrow) revert Ltv();
    }
}
