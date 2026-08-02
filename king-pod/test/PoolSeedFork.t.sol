// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
}
interface INPM {
    struct MintParams {
        address token0; address token1; uint24 fee; int24 tickLower; int24 tickUpper;
        uint256 amount0Desired; uint256 amount1Desired; uint256 amount0Min; uint256 amount1Min;
        address recipient; uint256 deadline;
    }
    function createAndInitializePoolIfNecessary(address,address,uint24,uint160) external payable returns (address);
    function mint(MintParams calldata) external payable returns (uint256,uint128,uint256,uint256);
}
interface IFactory { function getPool(address,address,uint24) external view returns (address); }

contract PoolSeedFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant GOLD = 0x76822B470DeC1b94Df4219727288e7a196224853;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint24 constant FEE = 3000;
    int24 constant TICK_L = -887220;
    int24 constant TICK_U = 887220;
    function setUp() public { vm.createSelectFork(vm.envString("BASE_RPC_URL")); }
    function _sqrtEle() internal pure returns (uint160) { return 7922816251426433759354395033; } // raw 0.01
    function _sqrtGold() internal pure returns (uint160) { return 25054144837504793118641380156; } // raw 0.1

    function test_seed_pools() public {
        vm.startPrank(HOT);
        IERC20(ELE).approve(NPM, type(uint256).max);
        IERC20(GOLD).approve(NPM, type(uint256).max);
        IERC20(USDC).approve(NPM, type(uint256).max);

        address poolEle = IFactory(FACTORY).getPool(ELE, USDC, FEE);
        console2.log("poolEle", poolEle);
        (uint256 id1,,uint256 a0,uint256 a1) = INPM(NPM).mint(INPM.MintParams({
            token0: ELE, token1: USDC, fee: FEE,
            tickLower: TICK_L, tickUpper: TICK_U,
            amount0Desired: 1e8, amount1Desired: 1e6,
            amount0Min: 0, amount1Min: 0,
            recipient: HOT, deadline: block.timestamp + 3600
        }));
        console2.log("ele id", id1, a0, a1);

        address token0 = GOLD < USDC ? GOLD : USDC;
        address token1 = GOLD < USDC ? USDC : GOLD;
        address poolGold = INPM(NPM).createAndInitializePoolIfNecessary(token0, token1, FEE, _sqrtGold());
        console2.log("poolGold", poolGold);
        uint256 amt0 = token0 == GOLD ? 1e7 : 1e6; // 0.1 GOLD or 1 USDC
        uint256 amt1 = token0 == GOLD ? 1e6 : 1e7;
        (uint256 id2,,uint256 b0,uint256 b1) = INPM(NPM).mint(INPM.MintParams({
            token0: token0, token1: token1, fee: FEE,
            tickLower: TICK_L, tickUpper: TICK_U,
            amount0Desired: amt0, amount1Desired: amt1,
            amount0Min: 0, amount1Min: 0,
            recipient: HOT, deadline: block.timestamp + 3600
        }));
        console2.log("gold id", id2, b0, b1);
        vm.stopPrank();
    }
}
