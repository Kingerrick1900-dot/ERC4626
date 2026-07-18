// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactETHForTokens(uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, Route[] calldata routes) external view returns (uint256[] memory amounts);
}

interface IMorpho {
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
}

interface IOracle {
    function price() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaMorpho {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @notice ETH → Aerodrome cbETH → Morpho collateral → borrow 60% LTV USDC → yRSS (BRETT).
/// @dev Market: cbETH/USDC 86% LLTV 0x1c21c59df9db44bf6f645d854ee710a8ca17b479451447e9f56758aee10a2fad
contract CarryEthCbethBrett is Script {
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0xb40d93F44411D8C09aD17d7F88195eF9b05cCD96;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000; // 86%
    uint256 constant SAFE_LTV_BPS = 6000; // 60%
    uint256 constant GAS_RESERVE = 0.00012 ether;
    uint256 constant USDC_FLOOR = 1e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address king = vm.addr(pk);

        uint256 ethBal = king.balance;
        require(ethBal > GAS_RESERVE + 0.00005 ether, "ETH_LOW");
        uint256 swapEth = ethBal - GAS_RESERVE;

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({from: WETH, to: CBETH, stable: false, factory: AERO_FACTORY});

        uint256[] memory quoted = IAeroRouter(AERO).getAmountsOut(swapEth, routes);
        uint256 minOut = (quoted[1] * 95) / 100; // 5% slip
        console2.log("swapEth", swapEth);
        console2.log("quotedCbeth", quoted[1]);
        console2.log("minOut", minOut);

        IMorpho.MarketParams memory mp = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: CBETH,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        uint256 usdcBefore = IERC20(USDC).balanceOf(king);
        require(usdcBefore >= USDC_FLOOR, "USDC_FLOOR");

        vm.startBroadcast(pk);

        // 1) ETH → cbETH (Aerodrome)
        IAeroRouter(AERO).swapExactETHForTokens{value: swapEth}(
            minOut, routes, king, block.timestamp + 20 minutes
        );
        uint256 cbBal = IERC20(CBETH).balanceOf(king);
        console2.log("cbETH", cbBal);
        require(cbBal > 0, "NO_CBETH");

        // 2) Supply cbETH collateral on Morpho
        IERC20(CBETH).approve(MORPHO, cbBal);
        IMorpho(MORPHO).supplyCollateral(mp, cbBal, king, "");

        // 3) Borrow USDC at 60% LTV (market LLTV 86%)
        uint256 px = IOracle(ORACLE).price();
        uint256 collValue = (cbBal * px) / 1e36; // USDC raw
        uint256 borrowUsdc = (collValue * SAFE_LTV_BPS) / 10_000;
        // leave room; min 1 wei if tiny
        require(borrowUsdc > 0, "BORROW0");
        console2.log("collValueUSDC", collValue);
        console2.log("borrowUsdc", borrowUsdc);
        IMorpho(MORPHO).borrow(mp, borrowUsdc, 0, king, king);

        uint256 usdcGot = IERC20(USDC).balanceOf(king) - usdcBefore;
        console2.log("usdcGot", usdcGot);
        // Keep USDC floor on hot — only deposit the borrowed amount
        require(IERC20(USDC).balanceOf(king) >= usdcGot + USDC_FLOOR || usdcBefore >= USDC_FLOOR, "FLOOR");
        // Deposit only borrowed proceeds (hot floor untouched)
        IERC20(USDC).approve(YRSS, usdcGot);
        uint256 shares = IMetaMorpho(YRSS).deposit(usdcGot, king);

        vm.stopBroadcast();

        console2.log("yrssShares", shares);
        console2.log("yrssTotal", IMetaMorpho(YRSS).totalAssets());
        console2.log("hotUsdcAfter", IERC20(USDC).balanceOf(king));
        console2.log("hotEthAfter", king.balance);
        console2.log("hotCbethAfter", IERC20(CBETH).balanceOf(king));
    }
}
