// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownTakeWethIdle} from "../src/CrownTakeWethIdle.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

contract TakeWethIdleFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    uint256 constant ASK = 700_000e6;
    uint256 constant EQUITY = 380 ether;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_permissionless_poke_takes_idle_to_landing() public {
        address keeper = makeAddr("keeper"); // not king — anyone

        vm.startPrank(HOT);
        CrownTakeWethIdle take =
            new CrownTakeWethIdle(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID, HOT, EQUITY, ASK);
        IMorphoAuth(MORPHO).setAuthorization(address(take), true);
        deal(WETH, HOT, EQUITY);
        IERC20T(WETH).approve(address(take), type(uint256).max);
        vm.stopPrank();

        assertTrue(take.ready(), "ready");

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        vm.prank(keeper);
        take.poke();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
        console2.log("landingDelta", delta);
        assertEq(delta, ASK, "Landing MUST hit ask");
        assertEq(take.lastLandingCredit(), ASK);
    }

    function test_poke_reverts_without_equity() public {
        vm.startPrank(HOT);
        CrownTakeWethIdle take =
            new CrownTakeWethIdle(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID, HOT, EQUITY, ASK);
        IMorphoAuth(MORPHO).setAuthorization(address(take), true);
        IERC20T(WETH).approve(address(take), type(uint256).max);
        vm.stopPrank();

        assertFalse(take.ready());
        vm.expectRevert(CrownTakeWethIdle.EquityMiss.selector);
        take.poke();
    }
}
