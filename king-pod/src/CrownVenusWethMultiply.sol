// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Venus-style Morpho WETH/USDC multiply → Landing USDC residual.
/// Flash WETH + equity WETH → supply → borrow USDC → Aero buy-back flash WETH → residual USDC to Landing.

interface IERC20V {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IWETHV {
    function deposit() external payable;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
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
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IOracleV {
    function price() external view returns (uint256);
}

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract CrownVenusWethMultiply {
    IMorphoV public immutable morpho;
    IAeroRouter public immutable aero;
    IWETHV public immutable weth;
    IERC20V public immutable usdc;
    address public immutable king;
    address public immutable landing;
    address public immutable aeroFactory;
    IMorphoV.MarketParams public mp;

    uint256 public lastLandingCredit;
    uint256 public lastFlash;
    uint256 public lastEquity;
    uint256 public lastBorrow;

    constructor(
        address morpho_,
        address aero_,
        address weth_,
        address usdc_,
        address king_,
        address landing_,
        address aeroFactory_,
        bytes32 wethMarketId_
    ) {
        morpho = IMorphoV(morpho_);
        aero = IAeroRouter(aero_);
        weth = IWETHV(weth_);
        usdc = IERC20V(usdc_);
        king = king_;
        landing = landing_;
        aeroFactory = aeroFactory_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoV(morpho_).idToMarketParams(wethMarketId_);
        mp = IMorphoV.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function multiply(uint256 flashWeth, uint256 equityWeth, uint256 usdcBorrow) external payable {
        require(msg.sender == king, "KING");
        uint256 eq = equityWeth;
        if (msg.value > 0) {
            weth.deposit{value: msg.value}();
            eq += msg.value;
        }
        if (equityWeth > 0) {
            require(weth.transferFrom(king, address(this), equityWeth), "WETH");
            eq = equityWeth + msg.value;
        }
        lastEquity = eq;
        lastFlash = flashWeth;
        morpho.flashLoan(address(weth), flashWeth, abi.encode(eq, usdcBorrow));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint256 equityWeth, uint256 usdcBorrow) = abi.decode(data, (uint256, uint256));

        uint256 totalColl = assets + equityWeth;
        weth.approve(address(morpho), totalColl);
        morpho.supplyCollateral(mp, totalColl, address(this), "");
        morpho.borrow(mp, usdcBorrow, 0, address(this), address(this));
        lastBorrow = usdcBorrow;

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route(address(usdc), address(weth), false, aeroFactory);

        // Size USDC→WETH swap to recover flash WETH (with 1% buffer via incremental quote)
        uint256 usdcIn = _usdcForWeth(assets, routes);
        require(usdcIn > 0 && usdcIn < usdc.balanceOf(address(this)), "SWAP_SIZE");
        usdc.approve(address(aero), usdcIn);
        aero.swapExactTokensForTokens(usdcIn, assets, routes, address(this), block.timestamp);
        require(weth.balanceOf(address(this)) >= assets, "REPAY_WETH");

        uint256 credit = usdc.balanceOf(address(this));
        if (credit > 0) {
            require(usdc.transfer(landing, credit), "PUSH");
            lastLandingCredit = credit;
        }
        weth.approve(address(morpho), assets);
    }

    function _usdcForWeth(uint256 wethOut, IAeroRouter.Route[] memory routes) internal view returns (uint256) {
        // Rough from oracle then bump until getAmountsOut >= wethOut
        uint256 price = IOracleV(mp.oracle).price(); // WETH in USDC terms, 1e36 scale
        uint256 guess = wethOut * price / 1e36;
        guess = guess * 103 / 100; // +3% slippage buffer start
        for (uint256 i = 0; i < 12; i++) {
            uint256[] memory out = aero.getAmountsOut(guess, routes);
            if (out[out.length - 1] >= wethOut) return guess;
            guess = guess * 105 / 100;
        }
        return guess;
    }

    receive() external payable {}
}
