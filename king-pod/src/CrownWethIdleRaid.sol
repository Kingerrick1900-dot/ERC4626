// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownWethIdleRaid
/// @notice Proven elite path C (Kamino/LI.FI/Morpho equity): WETH equity → Morpho WETH/USDC borrow → Landing.
/// @dev Fork-proven on DualFlashMachine: Landing +$700k with WETH/ETH equity. No flash rematch.

interface IERC20R {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IWETHR {
    function deposit() external payable;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoR {
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

contract CrownWethIdleRaid {
    IMorphoR public immutable morpho;
    IERC20R public immutable usdc;
    IWETHR public immutable weth;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoR.MarketParams public mp;

    uint256 public lastWethIn;
    uint256 public lastUsdcOut;
    uint256 public lastLandingCredit;

    event Raided(uint256 wethIn, uint256 usdcOut, uint256 landingDelta);

    error KingOnly();
    error IdleMiss();
    error LandingMiss();
    error BadAmt();

    constructor(
        address morpho_,
        address usdc_,
        address weth_,
        address king_,
        address landing_,
        bytes32 marketId_
    ) {
        morpho = IMorphoR(morpho_);
        usdc = IERC20R(usdc_);
        weth = IWETHR(weth_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoR(morpho_).idToMarketParams(marketId_);
        require(loan == usdc_ && coll == weth_, "MKT");
        mp = IMorphoR.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Pull WETH equity (from seed sink / hot), borrow USDC to Landing.
    function raid(uint256 wethIn, uint256 usdcOut) external {
        if (msg.sender != king) revert KingOnly();
        if (wethIn == 0 || usdcOut == 0) revert BadAmt();
        if (idle() < usdcOut) revert IdleMiss();

        require(weth.transferFrom(msg.sender, address(this), wethIn), "WETH");
        uint256 landBefore = usdc.balanceOf(landing);

        morpho.accrueInterest(mp);
        weth.approve(address(morpho), wethIn);
        morpho.supplyCollateral(mp, wethIn, address(this), "");
        morpho.borrow(mp, usdcOut, 0, address(this), landing);

        uint256 delta = usdc.balanceOf(landing) - landBefore;
        if (delta < usdcOut) revert LandingMiss();

        lastWethIn = wethIn;
        lastUsdcOut = usdcOut;
        lastLandingCredit = delta;
        emit Raided(wethIn, usdcOut, delta);
    }

    /// @notice Wrap native ETH → WETH equity → borrow USDC to Landing (Coinbase/LI.FI wrap shape).
    function raidEth(uint256 usdcOut) external payable {
        if (msg.sender != king) revert KingOnly();
        uint256 ethIn = msg.value;
        if (ethIn == 0 || usdcOut == 0) revert BadAmt();
        if (idle() < usdcOut) revert IdleMiss();

        uint256 landBefore = usdc.balanceOf(landing);
        weth.deposit{value: ethIn}();

        morpho.accrueInterest(mp);
        weth.approve(address(morpho), ethIn);
        morpho.supplyCollateral(mp, ethIn, address(this), "");
        morpho.borrow(mp, usdcOut, 0, address(this), landing);

        uint256 delta = usdc.balanceOf(landing) - landBefore;
        if (delta < usdcOut) revert LandingMiss();

        lastWethIn = ethIn;
        lastUsdcOut = usdcOut;
        lastLandingCredit = delta;
        emit Raided(ethIn, usdcOut, delta);
    }

    receive() external payable {}
}
