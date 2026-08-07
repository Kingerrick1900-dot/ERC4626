// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownKaminoMultiply
/// @notice EXACT Kamino Multiply — not Morpho rematch.
///
/// Kamino docs (how-it-works):
///   1. User deposit (equity)
///   2. Flash-borrow debt asset
///   3. Swap flash (+ optional deposit) → collateral asset
///   4. Deposit full collateral into lend market
///   5. Borrow debt against collateral
///   6. Borrowed debt repays the flash
///   7. Position remains (seed). Any surplus debt → Landing (King scoreboard).
///
/// Market: Morpho WETH/USDC on Base (real USDC idle ≥ $7M) — Kamino needs foreign idle
/// to borrow the flash repay. RSS/$1200 self-match has ~0 idle → cannot be Kamino.
///
/// HARD LAW: do not live-fire unless Landing USDC increases by `wantLanding`.

interface IERC20K {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoK {
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

interface IAeroPairK {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract CrownKaminoMultiply {
    IMorphoK public immutable morpho;
    IERC20K public immutable usdc;
    IERC20K public immutable weth;
    IAeroPairK public immutable aeroWethUsdc; // deep WETH/USDC — real swap depth
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoK.MarketParams public mp;
    bool public immutable wethIsToken0;

    uint256 public lastFlash;
    uint256 public lastEquityWeth;
    uint256 public lastWethSupplied;
    uint256 public lastBorrowed;
    uint256 public lastLandingCredit;
    bool public lastClosed;

    event KaminoMultiply(
        uint256 flash,
        uint256 equityWeth,
        uint256 wethSupplied,
        uint256 borrowed,
        uint256 landingCredit,
        bool closed
    );

    error KingOnly();
    error IdleMiss();
    error CloseFail();
    error LandingMiss();
    error Slippage();

    constructor(
        address morpho_,
        address usdc_,
        address weth_,
        address aeroWethUsdc_,
        address king_,
        address landing_,
        bytes32 marketId_
    ) {
        morpho = IMorphoK(morpho_);
        usdc = IERC20K(usdc_);
        weth = IERC20K(weth_);
        aeroWethUsdc = IAeroPairK(aeroWethUsdc_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        wethIsToken0 = IAeroPairK(aeroWethUsdc_).token0() == weth_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoK(morpho_).idToMarketParams(marketId_);
        require(loan == usdc_ && coll == weth_, "MKT");
        mp = IMorphoK.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Exact Kamino Multiply. Surplus borrow `wantLanding` → Landing.
    /// @param equityWeth User deposit (WETH). Required — LTV < 100%.
    /// @param flashAmount Debt flash (USDC), swapped → WETH.
    /// @param wantLanding USDC that must hit Landing (0 = position seed only).
    /// @param minWethFromSwap Slippage floor on USDC→WETH swap.
    function multiply(uint256 equityWeth, uint256 flashAmount, uint256 wantLanding, uint256 minWethFromSwap)
        external
    {
        if (msg.sender != king) revert KingOnly();
        if (equityWeth > 0) {
            require(weth.transferFrom(king, address(this), equityWeth), "EQ");
        }
        uint256 landBefore = usdc.balanceOf(landing);
        morpho.flashLoan(
            address(usdc),
            flashAmount,
            abi.encode(equityWeth, flashAmount, wantLanding, minWethFromSwap, landBefore)
        );
        // HARD LAW: if King asked for Landing credit, it must hit — else full revert.
        if (wantLanding > 0 && usdc.balanceOf(landing) < landBefore + wantLanding) revert LandingMiss();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (
            uint256 equityWeth,
            uint256 flashAmount,
            uint256 wantLanding,
            uint256 minWethFromSwap,
            /* landBefore */
        ) = abi.decode(data, (uint256, uint256, uint256, uint256, uint256));
        require(assets == flashAmount, "AMT");

        morpho.accrueInterest(mp);

        // Kamino step 3: swap flash debt → collateral (USDC → WETH) on deep pool
        uint256 wethFromSwap = _swapUsdcForWeth(flashAmount);
        if (wethFromSwap < minWethFromSwap) revert Slippage();

        // Kamino step 4: deposit full collateral (user equity + swapped)
        uint256 wethTotal = weth.balanceOf(address(this));
        weth.approve(address(morpho), wethTotal);
        morpho.supplyCollateral(mp, wethTotal, king, "");

        // Kamino step 5–6: borrow debt to repay flash; surplus → Landing
        uint256 borrowTotal = flashAmount + wantLanding;
        uint256 idleNow = idle();
        if (idleNow < borrowTotal) revert IdleMiss();

        morpho.borrow(mp, borrowTotal, 0, king, address(this));

        uint256 onRouter = usdc.balanceOf(address(this));
        if (onRouter < flashAmount + wantLanding) revert CloseFail();

        if (wantLanding > 0) {
            require(usdc.transfer(landing, wantLanding), "LAND");
        }

        lastFlash = flashAmount;
        lastEquityWeth = equityWeth;
        lastWethSupplied = wethTotal;
        lastBorrowed = borrowTotal;
        lastLandingCredit = wantLanding;
        lastClosed = true;

        // Kamino step 6: approve Morpho to pull flash repay
        usdc.approve(address(morpho), flashAmount);
        emit KaminoMultiply(flashAmount, equityWeth, wethTotal, borrowTotal, wantLanding, true);
    }

    function _swapUsdcForWeth(uint256 usdcIn) internal returns (uint256 wethOut) {
        (uint112 r0, uint112 r1,) = aeroWethUsdc.getReserves();
        uint256 reserveUsdc = wethIsToken0 ? uint256(r1) : uint256(r0);
        uint256 reserveWeth = wethIsToken0 ? uint256(r0) : uint256(r1);
        // Aero 0.3% fee
        uint256 amountInWithFee = usdcIn * 997;
        wethOut = (amountInWithFee * reserveWeth) / (reserveUsdc * 1000 + amountInWithFee);
        require(wethOut > 0, "OUT");
        require(usdc.transfer(address(aeroWethUsdc), usdcIn), "IN");
        if (wethIsToken0) {
            aeroWethUsdc.swap(wethOut, 0, address(this), "");
        } else {
            aeroWethUsdc.swap(0, wethOut, address(this), "");
        }
    }
}
