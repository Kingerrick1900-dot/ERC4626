// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownTakeWethIdle
/// @notice Morpho WETH/USDC idle TAKE — Layer W in ZK-layered Landing stack.
/// @dev supplyCollateral(WETH) → borrow(USDC → Landing). Permissionless `poke`.
///      Hard law: Landing Δ == ask or full revert.
///
/// Equity is ENGINEERED — hot does not hold ~380 WETH inventory. That figure is the
/// 86% LLTV ask for $700k, not a balance. Primary unlock is ZK pack (flash-bound
/// BoundReservesGate) + named credit; this contract is the blue-chip idle layer when
/// WETH equity has been engineered (desk/seed/wrap/flash+buffer). See
/// CrownZkLayeredLanding.

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IWETHT {
    function deposit() external payable;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

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

interface IOracleT {
    function price() external view returns (uint256);
}

contract CrownTakeWethIdle {
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;

    IMorphoT public immutable morpho;
    IERC20T public immutable usdc;
    IWETHT public immutable weth;
    IOracleT public immutable oracle;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoT.MarketParams public mp;

    uint256 public minWethEquity; // poke gate
    uint256 public askUsdc; // Landing target
    address public equitySource; // hot / seed sink — WETH pulled from here
    bool public paused;

    uint256 public lastWethIn;
    uint256 public lastUsdcOut;
    uint256 public lastLandingCredit;

    event Armed(uint256 minWethEquity, uint256 askUsdc, address equitySource);
    event Took(address indexed caller, uint256 wethIn, uint256 usdcOut, uint256 landingDelta);
    event Paused(bool paused);

    error KingOnly();
    error PausedErr();
    error IdleMiss();
    error EquityMiss();
    error LandingMiss();
    error BadAmt();
    error Ltv();

    modifier onlyKing() {
        if (msg.sender != king) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address weth_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address equitySource_,
        uint256 minWethEquity_,
        uint256 askUsdc_
    ) {
        morpho = IMorphoT(morpho_);
        usdc = IERC20T(usdc_);
        weth = IWETHT(weth_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        equitySource = equitySource_;
        minWethEquity = minWethEquity_;
        askUsdc = askUsdc_;
        (address loan, address coll, address oracle_, address irm, uint256 lltv) =
            IMorphoT(morpho_).idToMarketParams(marketId_);
        require(loan == usdc_ && coll == weth_, "MKT");
        oracle = IOracleT(oracle_);
        mp = IMorphoT.MarketParams(loan, coll, oracle_, irm, lltv);
        emit Armed(minWethEquity_, askUsdc_, equitySource_);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function maxBorrowUsdc(uint256 wethIn) public view returns (uint256) {
        uint256 collValue = wethIn * oracle.price() / ORACLE_PRICE_SCALE; // USDC 6dp
        return collValue * mp.lltv / 1e18;
    }

    function ready() public view returns (bool) {
        if (paused) return false;
        uint256 eq = weth.balanceOf(equitySource);
        if (eq < minWethEquity) return false;
        if (idle() < askUsdc) return false;
        if (maxBorrowUsdc(eq) < askUsdc) return false;
        return true;
    }

    function arm(uint256 minWethEquity_, uint256 askUsdc_, address equitySource_) external onlyKing {
        if (askUsdc_ == 0 || equitySource_ == address(0)) revert BadAmt();
        minWethEquity = minWethEquity_;
        askUsdc = askUsdc_;
        equitySource = equitySource_;
        emit Armed(minWethEquity_, askUsdc_, equitySource_);
    }

    function setPaused(bool p) external onlyKing {
        paused = p;
        emit Paused(p);
    }

    /// @notice Permissionless TAKE. Anyone triggers when equity + idle are live.
    /// @dev Pulls full equity balance (Morpho holds surplus as coll). Exact-ceil trim
    ///      is unsafe under Morpho's double-truncation (price then LLTV).
    function poke() external returns (uint256 landingDelta) {
        if (paused) revert PausedErr();
        uint256 wethIn = weth.balanceOf(equitySource);
        if (wethIn < minWethEquity) revert EquityMiss();
        uint256 usdcOut = askUsdc;
        if (usdcOut == 0) revert BadAmt();
        if (idle() < usdcOut) revert IdleMiss();
        if (maxBorrowUsdc(wethIn) < usdcOut) revert Ltv();

        landingDelta = _take(wethIn, usdcOut);
    }

    /// @notice King direct TAKE (sized).
    function take(uint256 wethIn, uint256 usdcOut) external onlyKing returns (uint256) {
        if (paused) revert PausedErr();
        return _take(wethIn, usdcOut);
    }

    /// @notice Wrap ETH equity then TAKE (Coinbase/LI.FI wrap shape).
    function takeEth(uint256 usdcOut) external payable onlyKing returns (uint256) {
        if (paused) revert PausedErr();
        uint256 ethIn = msg.value;
        if (ethIn == 0 || usdcOut == 0) revert BadAmt();
        if (idle() < usdcOut) revert IdleMiss();
        weth.deposit{value: ethIn}();
        // WETH now on this contract — supply from self
        return _takeFromSelf(ethIn, usdcOut);
    }

    function _take(uint256 wethIn, uint256 usdcOut) internal returns (uint256 landingDelta) {
        if (wethIn == 0 || usdcOut == 0) revert BadAmt();
        if (idle() < usdcOut) revert IdleMiss();
        if (maxBorrowUsdc(wethIn) < usdcOut) revert Ltv();

        require(weth.transferFrom(equitySource, address(this), wethIn), "WETH");
        landingDelta = _takeFromSelf(wethIn, usdcOut);
    }

    function _takeFromSelf(uint256 wethIn, uint256 usdcOut) internal returns (uint256 landingDelta) {
        uint256 landBefore = usdc.balanceOf(landing);

        morpho.accrueInterest(mp);
        weth.approve(address(morpho), wethIn);
        morpho.supplyCollateral(mp, wethIn, address(this), "");
        morpho.borrow(mp, usdcOut, 0, address(this), landing);

        landingDelta = usdc.balanceOf(landing) - landBefore;
        if (landingDelta < usdcOut) revert LandingMiss();

        lastWethIn = wethIn;
        lastUsdcOut = usdcOut;
        lastLandingCredit = landingDelta;
        emit Took(msg.sender, wethIn, usdcOut, landingDelta);
    }

    receive() external payable {}
}
