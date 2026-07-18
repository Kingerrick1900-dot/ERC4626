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

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
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

/// @notice Controlled scaler: ETH → Aerodrome cbETH → Morpho 60% LTV borrow → yRSS/BRETT.
/// @dev OPS WALLET = LOOP `0x8d3cfbFc…8585` ONLY. Never fund/run this from hot `0x6708…`.
///   LOOP_PRIVATE_KEY (required) — signer must be loop
///   ETH_IN          — wei to swap (0 = balance - GAS_RESERVE)
///   MAX_LTV_BPS     — default 6000 (60%)
///   SLIPPAGE_BPS    — default 500 (5%)
///   GAS_RESERVE     — default 0.0003 ether
///   USDC_FLOOR      — default 1e6 ($1) on loop
///   LOOPS           — default 1 (not recursive leverage)
contract CarryLoopScaler is Script {
    address constant OPS_LOOP = 0x8d3cfbFc6A276f118579517E4d166e94C66F8585;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0xb40d93F44411D8C09aD17d7F88195eF9b05cCD96;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;
    bytes32 constant CBETH_MARKET =
        0x1c21c59df9db44bf6f645d854ee710a8ca17b479451447e9f56758aee10a2fad;
    bytes32 constant BRETT_MARKET =
        0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function run() external {
        // Prefer LOOP_PRIVATE_KEY; refuse if signer is not the loop ops wallet.
        uint256 pk = vm.envOr("LOOP_PRIVATE_KEY", uint256(0));
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        address king = vm.addr(pk);
        require(king == OPS_LOOP, "OPS_MUST_BE_LOOP");

        uint256 maxLtvBps = vm.envOr("MAX_LTV_BPS", uint256(6000));
        uint256 slipBps = vm.envOr("SLIPPAGE_BPS", uint256(500));
        uint256 gasReserve = vm.envOr("GAS_RESERVE", uint256(0.0003 ether));
        uint256 usdcFloor = vm.envOr("USDC_FLOOR", uint256(1e6));
        uint256 loops = vm.envOr("LOOPS", uint256(1));
        require(maxLtvBps > 0 && maxLtvBps <= 7000, "LTV");
        require(loops >= 1 && loops <= 5, "LOOPS");

        IMorpho.MarketParams memory mp = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: CBETH,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({from: WETH, to: CBETH, stable: false, factory: AERO_FACTORY});

        uint256 ethInCfg = vm.envOr("ETH_IN", uint256(0));

        for (uint256 i = 0; i < loops; i++) {
            uint256 ethBal = king.balance;
            require(ethBal > gasReserve + 0.00005 ether, "ETH_LOW");

            uint256 swapEth = ethInCfg > 0 ? ethInCfg : (ethBal - gasReserve);
            if (swapEth + gasReserve > ethBal) {
                swapEth = ethBal - gasReserve;
            }
            require(swapEth >= 0.00005 ether, "ETH_IN_DUST");

            uint256[] memory quoted = IAeroRouter(AERO).getAmountsOut(swapEth, routes);
            uint256 minOut = (quoted[1] * (10_000 - slipBps)) / 10_000;
            console2.log("lap", i);
            console2.log("swapEth", swapEth);
            console2.log("quotedCbeth", quoted[1]);

            uint256 usdcBefore = IERC20(USDC).balanceOf(king);
            require(usdcBefore >= usdcFloor, "USDC_FLOOR");

            vm.startBroadcast(pk);

            IAeroRouter(AERO).swapExactETHForTokens{value: swapEth}(
                minOut, routes, king, block.timestamp + 20 minutes
            );
            uint256 cbBal = IERC20(CBETH).balanceOf(king);
            require(cbBal > 0, "NO_CBETH");

            IERC20(CBETH).approve(MORPHO, cbBal);
            IMorpho(MORPHO).supplyCollateral(mp, cbBal, king, "");

            uint256 px = IOracle(ORACLE).price();
            uint256 collValue = (cbBal * px) / 1e36;
            uint256 borrowUsdc = (collValue * maxLtvBps) / 10_000;
            require(borrowUsdc > 0, "BORROW0");
            // Keep a 2% buffer under target LTV for interest accrual
            borrowUsdc = (borrowUsdc * 98) / 100;
            require(borrowUsdc > 0, "BORROW0");
            console2.log("collValueUSDC", collValue);
            console2.log("borrowUsdc", borrowUsdc);

            IMorpho(MORPHO).borrow(mp, borrowUsdc, 0, king, king);
            uint256 usdcGot = IERC20(USDC).balanceOf(king) - usdcBefore;
            require(IERC20(USDC).balanceOf(king) >= usdcFloor, "FLOOR_AFTER");
            // Deposit only borrowed proceeds — leave prior USDC floor intact
            if (usdcGot > usdcFloor && usdcBefore < usdcFloor) {
                usdcGot = IERC20(USDC).balanceOf(king) - usdcFloor;
            }
            // If we already had floor, deposit full borrowed amount
            uint256 toDeposit = IERC20(USDC).balanceOf(king) - usdcFloor;
            // Cap deposit to what this lap produced (don't sweep older USDC beyond floor)
            if (toDeposit > usdcGot) toDeposit = usdcGot;
            require(toDeposit > 0, "DEPOSIT0");

            IERC20(USDC).approve(YRSS, toDeposit);
            uint256 shares = IMetaMorpho(YRSS).deposit(toDeposit, king);

            vm.stopBroadcast();

            (, uint128 bShares, uint128 coll) = IMorpho(MORPHO).position(CBETH_MARKET, king);
            console2.log("yrssShares", shares);
            console2.log("yrssTotal", IMetaMorpho(YRSS).totalAssets());
            console2.log("posCollateral", uint256(coll));
            console2.log("posBorrowShares", uint256(bShares));
            console2.log("hotUsdc", IERC20(USDC).balanceOf(king));
            console2.log("hotEth", king.balance);

            // Only first lap uses explicit ETH_IN; further laps use remaining balance
            ethInCfg = 0;
        }
    }
}
