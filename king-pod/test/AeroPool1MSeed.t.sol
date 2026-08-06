// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownAeroPool1MSeed} from "../src/CrownAeroPool1MSeed.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IAeroPairT {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
}

/// @notice Fork-prove Aero RSS/USDC pool can LOOK like ≥ $1M USDC (live is ~$0.67).
contract AeroPool1MSeedFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant POOL = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;

    uint256 constant LOOK = 1_000_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_ephemeral_pool_looks_like_1M_usdc() public {
        uint256 beforePool = IERC20T(USDC).balanceOf(POOL);
        uint256 beforeLand = IERC20T(USDC).balanceOf(LANDING);
        console2.log("pool USDC before", beforePool);

        // Free RSS on hot — reclaim gun after donate+sync.
        // ~$25k USDC buffer covers Aero fee + CP gap (reclaim cannot return 100% of stuffed USDC).
        uint256 rssMax = 9_000_000e18;
        uint256 buffer = 25_000e6;

        vm.startPrank(HOT);
        CrownAeroPool1MSeed seeder =
            new CrownAeroPool1MSeed(MORPHO, USDC, RSS, POOL, HOT, LANDING);
        deal(USDC, HOT, buffer);
        IERC20T(RSS).approve(address(seeder), rssMax);
        IERC20T(USDC).approve(address(seeder), buffer);
        seeder.lookEphemeral(LOOK, rssMax, buffer);
        vm.stopPrank();

        console2.log("pool USDC peak (in-tx)", seeder.lastPoolUsdcPeak());
        console2.log("pool USDC after", IERC20T(USDC).balanceOf(POOL));
        console2.log("rss spent", seeder.lastRssSpent());
        console2.log("Landing residual", seeder.lastResidualUsdc());
        console2.log("Landing delta", IERC20T(USDC).balanceOf(LANDING) - beforeLand);

        assertGe(seeder.lastPoolUsdcPeak(), LOOK, "peak LOOK miss");
    }

    function test_persist_1M_with_real_usdc() public {
        vm.startPrank(HOT);
        CrownAeroPool1MSeed seeder =
            new CrownAeroPool1MSeed(MORPHO, USDC, RSS, POOL, HOT, LANDING);
        deal(USDC, HOT, LOOK);
        IERC20T(USDC).approve(address(seeder), LOOK);
        seeder.lookPersist(LOOK);
        vm.stopPrank();

        uint256 poolAfter = IERC20T(USDC).balanceOf(POOL);
        console2.log("PERSIST pool USDC", poolAfter);
        console2.log("PERSIST peak", seeder.lastPoolUsdcPeak());
        assertGe(poolAfter, LOOK, "persist pool miss");
        assertGe(seeder.lastPoolUsdcPeak(), LOOK, "persist peak miss");
    }

    function test_persist_flash_prefund_repay() public {
        vm.startPrank(HOT);
        CrownAeroPool1MSeed seeder =
            new CrownAeroPool1MSeed(MORPHO, USDC, RSS, POOL, HOT, LANDING);
        // Prefund repay so flashed USDC can STAY in pool
        deal(USDC, address(seeder), LOOK);
        seeder.lookPersistFlash(LOOK);
        vm.stopPrank();

        uint256 poolAfter = IERC20T(USDC).balanceOf(POOL);
        console2.log("PERSIST_FLASH pool USDC", poolAfter);
        console2.log("PERSIST_FLASH peak", seeder.lastPoolUsdcPeak());
        assertGe(poolAfter, LOOK, "persist-flash pool miss");
        assertGe(seeder.lastPoolUsdcPeak(), LOOK, "persist-flash peak miss");
    }
}
