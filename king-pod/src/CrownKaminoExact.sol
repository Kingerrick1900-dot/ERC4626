// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownKaminoExact
/// @notice EXACT Kamino Multiply — same steps, RSS/USDC (not WETH).
///
/// Kamino (USDe/USDG):
///   1. User deposit collateral (USDe)
///   2. Flash debt (USDG)
///   3. Swap flash debt → collateral (USDG → USDe)
///   4. Deposit equity + swapped collateral
///   5. Borrow debt to repay flash
///   6. Surplus debt → user
///
/// This chassis (RSS/USDC):
///   1. User deposit = free RSS
///   2. Flash USDC
///   3. Swap USDC → RSS (Aero)
///   4. supplyCollateral all RSS
///   5. Borrow USDC to repay flash
///   6. wantLanding → Landing
///
/// HARD LAW: revert if wantLanding set and Landing USDC does not increase by wantLanding.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
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

interface IAeroPair {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract CrownKaminoExact {
    IMorpho public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IAeroPair public immutable aero;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorpho.MarketParams public mp;
    bool public immutable rssIsToken0;

    uint256 public lastFlash;
    uint256 public lastEquityRss;
    uint256 public lastRssSupplied;
    uint256 public lastBorrowed;
    uint256 public lastLandingCredit;
    bool public lastClosed;

    event KaminoExact(
        uint256 flash, uint256 equityRss, uint256 rssSupplied, uint256 borrowed, uint256 landingCredit, bool closed
    );

    error KingOnly();
    error IdleMiss();
    error CloseFail();
    error LandingMiss();
    error Slippage();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address aero_,
        address king_,
        address landing_,
        bytes32 marketId_
    ) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        aero = IAeroPair(aero_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        rssIsToken0 = IAeroPair(aero_).token0() == rss_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorpho(morpho_).idToMarketParams(marketId_);
        require(loan == usdc_ && coll == rss_, "MKT");
        mp = IMorpho.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Exact Kamino Multiply. equityRss = free RSS (user deposit). wantLanding → Landing.
    function multiply(uint256 equityRss, uint256 flashAmount, uint256 wantLanding, uint256 minRssFromSwap)
        external
    {
        if (msg.sender != king) revert KingOnly();
        if (equityRss > 0) require(rss.transferFrom(king, address(this), equityRss), "EQ");
        uint256 landBefore = usdc.balanceOf(landing);
        morpho.flashLoan(
            address(usdc), flashAmount, abi.encode(equityRss, flashAmount, wantLanding, minRssFromSwap, landBefore)
        );
        if (wantLanding > 0 && usdc.balanceOf(landing) < landBefore + wantLanding) revert LandingMiss();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint256 equityRss, uint256 flashAmount, uint256 wantLanding, uint256 minRssFromSwap,) =
            abi.decode(data, (uint256, uint256, uint256, uint256, uint256));
        require(assets == flashAmount, "AMT");

        morpho.accrueInterest(mp);

        // Kamino step 3: swap flash debt → collateral (USDC → RSS)
        uint256 rssFromSwap = _swapUsdcForRss(flashAmount);
        if (rssFromSwap < minRssFromSwap) revert Slippage();

        // Kamino step 4: deposit equity + swapped collateral
        uint256 rssTotal = rss.balanceOf(address(this));
        rss.approve(address(morpho), rssTotal);
        morpho.supplyCollateral(mp, rssTotal, king, "");

        // Kamino step 5–6: borrow debt to repay flash; surplus → Landing
        uint256 borrowTotal = flashAmount + wantLanding;
        if (idle() < borrowTotal) revert IdleMiss();
        morpho.borrow(mp, borrowTotal, 0, king, address(this));

        uint256 onRouter = usdc.balanceOf(address(this));
        if (onRouter < borrowTotal) revert CloseFail();
        if (wantLanding > 0) require(usdc.transfer(landing, wantLanding), "LAND");

        lastFlash = flashAmount;
        lastEquityRss = equityRss;
        lastRssSupplied = rssTotal;
        lastBorrowed = borrowTotal;
        lastLandingCredit = wantLanding;
        lastClosed = true;

        usdc.approve(address(morpho), flashAmount);
        emit KaminoExact(flashAmount, equityRss, rssTotal, borrowTotal, wantLanding, true);
    }

    function _swapUsdcForRss(uint256 usdcIn) internal returns (uint256 rssOut) {
        (uint112 r0, uint112 r1,) = aero.getReserves();
        uint256 reserveRss = rssIsToken0 ? uint256(r0) : uint256(r1);
        uint256 reserveUsdc = rssIsToken0 ? uint256(r1) : uint256(r0);
        uint256 amountInWithFee = usdcIn * 997;
        rssOut = (amountInWithFee * reserveRss) / (reserveUsdc * 1000 + amountInWithFee);
        require(rssOut > 0 && rssOut < reserveRss, "OUT");
        require(usdc.transfer(address(aero), usdcIn), "IN");
        if (rssIsToken0) {
            aero.swap(rssOut, 0, address(this), "");
        } else {
            aero.swap(0, rssOut, address(this), "");
        }
    }
}
