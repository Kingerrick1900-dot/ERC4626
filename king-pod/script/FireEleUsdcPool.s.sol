// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

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

interface INpm {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool);
    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

/// @notice Create UniV3 ELE/USDC @ $1, seed from hot. KING_GO=1 FIRE_ELE_POOL=1
/// @dev No timelock. token0=ELE < token1=USDC. Keep MIN_ETH for later gas.
contract FireEleUsdcPool is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACT = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    uint24 constant FEE = 3000; // 0.3% — new token
    int24 constant TICK_SPACING = 60;
    uint256 constant MIN_ETH = 3e14; // 0.0003 ETH gas floor

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ELE_POOL", uint256(0)) == 1, "NEED FIRE_ELE_POOL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        // Optional dust ETH→USDC (keep gas floor)
        uint256 ethBal = HOT.balance;
        if (ethBal > MIN_ETH + 5e13) {
            uint256 swapEth = ethBal - MIN_ETH;
            if (swapEth > 2e14) swapEth = 2e14;
            IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
            routes[0] = IAeroRouter.Route({from: WETH, to: USDC, stable: false, factory: AERO_FACT});
            uint256[] memory quoted = IAeroRouter(AERO).getAmountsOut(swapEth, routes);
            uint256 minOut = (quoted[1] * 90) / 100;
            vm.startBroadcast(pk);
            IAeroRouter(AERO).swapExactETHForTokens{value: swapEth}(minOut, routes, HOT, block.timestamp + 600);
            vm.stopBroadcast();
        }

        uint256 usdcBal = IERC20P(USDC).balanceOf(HOT);
        require(usdcBal >= 1e6, "NEED_>=1_USDC");
        // leave $1 USDC liquid for ops; seed rest (or all-but-dust)
        uint256 seedUsdc = usdcBal > 2e6 ? usdcBal - 1e6 : usdcBal;
        // ELE 8dp, USDC 6dp @ $1 → seedEle = seedUsdc * 1e2
        uint256 seedEle = seedUsdc * 100;
        uint256 eleBal = IERC20P(ELE).balanceOf(HOT);
        if (seedEle > eleBal) {
            seedEle = eleBal;
            seedUsdc = seedEle / 100;
        }
        require(seedUsdc >= 1e6 && seedEle >= 1e8, "SEED_DUST");

        // token0 = ELE, token1 = USDC (ELE address < USDC)
        // price = token1/token0 = 1e6/1e8 = 0.01 → sqrtPriceX96 = 2^96 / 10
        uint160 sqrtPriceX96 = uint160(uint256(1 << 96) / 10);

        vm.startBroadcast(pk);
        address pool = INpm(NPM).createAndInitializePoolIfNecessary(ELE, USDC, FEE, sqrtPriceX96);
        console2.log("POOL", pool);

        IERC20P(USDC).approve(NPM, seedUsdc);
        IERC20P(ELE).approve(NPM, seedEle);

        int24 tickLower = (int24(-887220) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = (int24(887220) / TICK_SPACING) * TICK_SPACING;

        (uint256 tokenId, uint128 liq, uint256 a0, uint256 a1) = INpm(NPM).mint(
            INpm.MintParams({
                token0: ELE,
                token1: USDC,
                fee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: seedEle,
                amount1Desired: seedUsdc,
                amount0Min: 0,
                amount1Min: 0,
                recipient: HOT,
                deadline: block.timestamp + 600
            })
        );
        vm.stopBroadcast();

        console2.log("tokenId", tokenId);
        console2.log("liquidity", uint256(liq));
        console2.log("amount0_ELE", a0);
        console2.log("amount1_USDC", a1);
        console2.log("usdcLeft", IERC20P(USDC).balanceOf(HOT));
        console2.log("eleLeft", IERC20P(ELE).balanceOf(HOT));
        console2.log("ethLeft", HOT.balance);
        console2.log("ELE_POOL_OK", uint256(1));
    }
}
