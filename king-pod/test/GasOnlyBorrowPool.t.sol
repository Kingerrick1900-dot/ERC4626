// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownGasOnlyBorrowPool} from "../src/CrownGasOnlyBorrowPool.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IYrssT {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory, uint256, uint256, address, bytes calldata) external returns (uint256, uint256);
}

contract GasOnlyBorrowPoolFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant FLASH_PACK = 0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant LLTV = 770000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_gas_park_creates_yrss_war_chest() public {
        uint256 assets0 = IYrssT(YRSS).totalAssets();
        uint256 shares0 = IYrssT(YRSS).balanceOf(HOT);

        vm.startPrank(HOT);
        CrownGasOnlyBorrowPool pool = new CrownGasOnlyBorrowPool(
            MORPHO, USDC, RSS, YRSS, ORACLE, FLASH_PACK, GATE, PA, HOT, LANDING, MID, IRM, LLTV, HOT
        );
        IMorphoAuth(MORPHO).setAuthorization(address(pool), true);
        IERC20T(RSS).approve(address(pool), type(uint256).max);
        pool.gasPark(2_000 ether, 1_000_000e6);
        vm.stopPrank();

        console2.log("yrssAssets before", assets0);
        console2.log("yrssAssets after", IYrssT(YRSS).totalAssets());
        assertEq(pool.lastParkUsdc(), 1_000_000e6);
        assertGt(IYrssT(YRSS).totalAssets(), assets0, "gas-only war chest");
        assertGt(IYrssT(YRSS).balanceOf(HOT), shares0, "king yRSS shares");
    }

    function test_unmatched_idle_poke_lands_over_700k() public {
        vm.startPrank(HOT);
        CrownGasOnlyBorrowPool pool = new CrownGasOnlyBorrowPool(
            MORPHO, USDC, RSS, YRSS, ORACLE, FLASH_PACK, GATE, PA, HOT, LANDING, MID, IRM, LLTV, HOT
        );
        IMorphoAuth(MORPHO).setAuthorization(address(pool), true);
        vm.stopPrank();

        // Unmatched LP depth (desk/Merkl/Lazy answering Peapods) — $2M > old 700k ceiling
        uint256 seed = 2_000_000e6;
        deal(USDC, address(this), seed);
        IERC20T(USDC).approve(MORPHO, seed);
        IMorphoT(MORPHO).supply(
            IMorphoT.MarketParams(USDC, RSS, ORACLE, IRM, LLTV), seed, 0, address(this), ""
        );
        assertGe(pool.idle(), seed);

        uint256 land0 = IERC20T(USDC).balanceOf(LANDING);
        pool.poke();
        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - land0;
        console2.log("Landing delta", delta);
        assertGe(delta, seed, "full idle to Landing");
        assertGt(delta, 700_000e6, "no 700k ceiling");
    }
}
