// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface INonfungiblePositionManagerP {
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

    function createAndInitializePoolIfNecessary(address, address, uint24, uint160) external payable returns (address);
    function mint(MintParams calldata) external payable returns (uint256, uint128, uint256, uint256);
}

interface IUniFactoryP {
    function getPool(address, address, uint24) external view returns (address);
}

/// @notice Light live sale-source pools for ELE and GOLD on Base with real USDC.
/// @dev Seeds existing ELE/USDC 0.3% pool and creates/seeds GOLD/USDC 0.3% pool.
contract SeedEleGoldSalesSource is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583; // 8dp
    address constant GOLD = 0x76822B470DeC1b94Df4219727288e7a196224853; // 8dp
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // 6dp

    uint24 constant FEE = 3000;
    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;

    uint256 constant ELE_SEED = 1e8; // 1 ELE
    uint256 constant GOLD_SEED = 1e7; // 0.1 GOLD
    uint256 constant USDC_PER_POOL = 1e6; // $1
    uint256 constant USDC_FLOOR = 1e6; // keep at least $1 on hot

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IERC20P(USDC).balanceOf(HOT) >= (USDC_PER_POOL * 2) + USDC_FLOOR, "NEED_3_USDC");

        vm.startBroadcast(pk);

        IERC20P(ELE).approve(NPM, type(uint256).max);
        IERC20P(GOLD).approve(NPM, type(uint256).max);
        IERC20P(USDC).approve(NPM, type(uint256).max);

        _seedEle();
        _seedGold();

        vm.stopBroadcast();

        console2.log("hotUsdcAfter", IERC20P(USDC).balanceOf(HOT));
    }

    function _seedEle() internal {
        address pool = IUniFactoryP(FACTORY).getPool(ELE, USDC, FEE);
        require(pool != address(0), "ELE_POOL_MISSING");
        (uint256 tokenId,, uint256 eleUsed, uint256 usdcUsed) = INonfungiblePositionManagerP(NPM).mint(
            INonfungiblePositionManagerP.MintParams({
                token0: ELE,
                token1: USDC,
                fee: FEE,
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                amount0Desired: ELE_SEED,
                amount1Desired: USDC_PER_POOL,
                amount0Min: 0,
                amount1Min: 0,
                recipient: HOT,
                deadline: block.timestamp + 1 hours
            })
        );
        console2.log("elePool", pool);
        console2.log("eleTokenId", tokenId);
        console2.log("eleUsed", eleUsed);
        console2.log("eleUsdcUsed", usdcUsed);
    }

    function _seedGold() internal {
        address token0 = GOLD < USDC ? GOLD : USDC;
        address token1 = GOLD < USDC ? USDC : GOLD;
        address pool = INonfungiblePositionManagerP(NPM).createAndInitializePoolIfNecessary(
            token0, token1, FEE, _sqrtPriceGoldUsdc()
        );

        uint256 amount0 = token0 == GOLD ? GOLD_SEED : USDC_PER_POOL;
        uint256 amount1 = token0 == GOLD ? USDC_PER_POOL : GOLD_SEED;
        (uint256 tokenId,, uint256 used0, uint256 used1) = INonfungiblePositionManagerP(NPM).mint(
            INonfungiblePositionManagerP.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE,
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: HOT,
                deadline: block.timestamp + 1 hours
            })
        );
        console2.log("goldPool", pool);
        console2.log("goldTokenId", tokenId);
        console2.log("goldUsed0", used0);
        console2.log("goldUsed1", used1);
    }

    /// @dev token0 = GOLD (8dp), token1 = USDC (6dp), target = 0.1 raw price = 10 USDC / 1 GOLD.
    function _sqrtPriceGoldUsdc() internal pure returns (uint160) {
        return 25054144837504793118641380156;
    }
}
