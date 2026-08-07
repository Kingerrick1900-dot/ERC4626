// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownVenusMultiply700k
/// @notice King's command: Venus / Kamino Multiply at $700k using free RSS equity.
///         Depth is engineered in-tx (Morpho idle manufacture) — empty Aero is not a veto.
///
/// Venus LeverageStrategiesManager / Kamino Multiply / Pendle PT flash:
///   1. Equity = free RSS from hot (collateralFromSender)
///   2. Flash USDC (temporary capital)
///   3. Engineer lending depth: `repay` manufactures idle past 100% util
///   4. `borrow` to this router repays the flash (close capital = debt on router)
///   5. Seed = residual Morpho position. Surplus above flash → Landing.
///
/// Research bottom line: seed is the POSITION. Landing Circle USDC = surplus only.

interface IERC20V {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoV {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
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

contract CrownVenusMultiply700k {
    uint256 public constant ASK = 700_000e6;

    IMorphoV public immutable morpho;
    IERC20V public immutable usdc;
    IERC20V public immutable rss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoV.MarketParams public mp;

    uint256 public lastFlash;
    uint256 public lastEquityRss;
    uint256 public lastPeakIdle;
    uint256 public lastSeedBorrow;
    uint256 public lastSurplusToLanding;
    bool public lastClosed;

    event VenusMultiply(
        uint256 flash,
        uint256 equityRss,
        uint256 peakIdle,
        uint256 seedBorrow,
        uint256 surplusToLanding,
        bool closed
    );

    error KingOnly();
    error IdleMiss();
    error CloseFail();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        address landing_,
        bytes32 marketId_
    ) {
        morpho = IMorphoV(morpho_);
        usdc = IERC20V(usdc_);
        rss = IERC20V(rss_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoV(morpho_).idToMarketParams(marketId_);
        mp = IMorphoV.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Venus Multiply $700k. `equityRss` = free tokens (use ~1k+ RSS; ~758 min at oracle).
    function multiply700k(uint256 equityRss) external {
        if (msg.sender != king) revert KingOnly();
        if (equityRss > 0) require(rss.transferFrom(king, address(this), equityRss), "RSS");
        morpho.flashLoan(address(usdc), ASK, abi.encode(equityRss, uint256(0)));
    }

    /// @notice Same multiply; request Landing surplus `want` (Venus leftover → sender).
    function multiplyLand700k(uint256 equityRss, uint256 wantLanding) external {
        if (msg.sender != king) revert KingOnly();
        if (equityRss > 0) require(rss.transferFrom(king, address(this), equityRss), "RSS");
        morpho.flashLoan(address(usdc), ASK, abi.encode(equityRss, wantLanding));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint256 equityRss, uint256 wantLanding) = abi.decode(data, (uint256, uint256));
        require(assets == ASK, "AMT");

        morpho.accrueInterest(mp);

        // Venus/Kamino: post equity collateral from sender
        if (equityRss > 0) {
            rss.approve(address(morpho), equityRss);
            morpho.supplyCollateral(mp, equityRss, king, "");
        }

        // Engineer past empty foreign depth: manufacture Morpho idle with the flash
        usdc.approve(address(morpho), ASK);
        morpho.repay(mp, ASK, 0, king, "");

        uint256 peak = idle();
        if (peak < ASK) revert IdleMiss();

        // Close = borrow to router (Venus/Seamless). Surplus above flash → Landing.
        uint256 borrowTotal = ASK + wantLanding;
        if (borrowTotal > peak) borrowTotal = peak;
        morpho.borrow(mp, borrowTotal, 0, king, address(this));

        uint256 onRouter = usdc.balanceOf(address(this));
        if (onRouter < ASK) revert CloseFail();

        uint256 surplus = onRouter - ASK;
        if (surplus > 0) require(usdc.transfer(landing, surplus), "LAND");

        lastFlash = ASK;
        lastEquityRss = equityRss;
        lastPeakIdle = peak;
        lastSeedBorrow = borrowTotal;
        lastSurplusToLanding = surplus;
        lastClosed = true;

        usdc.approve(address(morpho), ASK);
        emit VenusMultiply(ASK, equityRss, peak, borrowTotal, surplus, true);
    }
}
