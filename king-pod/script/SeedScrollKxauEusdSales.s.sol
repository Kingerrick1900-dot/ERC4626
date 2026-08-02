// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20S {
    function approve(address, uint256) external returns (bool);
}

interface INonfungiblePositionManagerS {
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

    function createAndInitializePoolIfNecessary(address, address, uint24, uint160)
        external
        payable
        returns (address);

    function mint(MintParams calldata) external payable returns (uint256, uint128, uint256, uint256);
}

interface IUniFactoryS {
    function getPool(address, address, uint24) external view returns (address);
}

/// @notice Dust seed Scroll kXAU/USDC, eUSD/USDC, kXAU/eUSD Uniswap V3 (0.3%).
/// @dev LIVE 2026-07-27 — deployments/SCROLL-KXAU-EUSD-SALES-SOURCE-LIVE.md
contract SeedScrollKxauEusdSales is Script {
    address constant FACTORY = 0x70C62C8b8e801124A4Aa81ce07b637A3e83cb919;
    address constant NPM = 0xB39002E4033b162fAc607fc3471E205FA2aE5967;
    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant KXAU = 0x156d912F37C179798D8396Da5d58919FA634262d; // 8dp
    address constant EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B; // 18dp
    uint24 constant FEE = 3000;
    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;

    // Live slot0 sqrtPriceX96 (create is no-op if pool exists)
    uint160 constant SQRT_KXAU_USDC = 250541448375047946302209916928;
    uint160 constant SQRT_EUSD_USDC = 79228162514264337593543950336000000;
    uint160 constant SQRT_KXAU_EUSD = 25054144837504791118539182250655744;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address hot = vm.addr(pk);
        vm.startBroadcast(pk);

        IERC20S(KXAU).approve(NPM, type(uint256).max);
        IERC20S(EUSD).approve(NPM, type(uint256).max);
        IERC20S(USDC).approve(NPM, type(uint256).max);

        _ensureAndMint(KXAU, USDC, SQRT_KXAU_USDC, 0.02e8, 200_000, hot);
        _ensureAndMint(EUSD, USDC, SQRT_EUSD_USDC, 0.2e18, 200_000, hot);
        _ensureAndMint(KXAU, EUSD, SQRT_KXAU_EUSD, 0.05e8, 0.5e18, hot);

        vm.stopBroadcast();
    }

    function _ensureAndMint(
        address a,
        address b,
        uint160 sqrtPriceX96,
        uint256 amtA,
        uint256 amtB,
        address recipient
    ) internal {
        (address t0, address t1) = a < b ? (a, b) : (b, a);
        bool aIs0 = (a == t0);

        address pool = IUniFactoryS(FACTORY).getPool(t0, t1, FEE);
        if (pool == address(0)) {
            pool = INonfungiblePositionManagerS(NPM).createAndInitializePoolIfNecessary(
                t0, t1, FEE, sqrtPriceX96
            );
            console2.log("created pool", pool);
        } else {
            console2.log("existing pool", pool);
        }

        INonfungiblePositionManagerS.MintParams memory p = INonfungiblePositionManagerS.MintParams({
            token0: t0,
            token1: t1,
            fee: FEE,
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            amount0Desired: aIs0 ? amtA : amtB,
            amount1Desired: aIs0 ? amtB : amtA,
            amount0Min: 0,
            amount1Min: 0,
            recipient: recipient,
            deadline: block.timestamp + 600
        });
        (uint256 tokenId, uint128 liq,,) = INonfungiblePositionManagerS(NPM).mint(p);
        console2.log("minted NFT", tokenId);
        console2.log("liquidity", uint256(liq));
    }
}
