// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownZkLayeredLanding} from "../src/CrownZkLayeredLanding.sol";
import {CrownTakeWethIdle} from "../src/CrownTakeWethIdle.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IBoundGateT {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, bool);
    function minThreshold() external view returns (uint256);
    function setAttestor(address, bool) external;
    function attestLive(address, uint256) external;
}

interface IZkCreditT {
    function maxBorrow(address) external view returns (uint256);
    function supply(uint256) external;
    function setOperator(address, bool) external;
}

/// @notice Fork tests: ZK pack layer is primary; WETH TAKE is optional engineer layer.
contract ZkLayeredLandingFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    address constant BOUND_GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant CREDIT = 0x20B1513a137b9CB166E2cC15c405e842278E7D1A;
    address constant FLASH = 0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4;
    address constant AUTODRAW = 0x364bEF6c5A3DC2c02D7ECf1e12a2d1F08B0513ba;

    uint256 constant ASK = 700_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_live_pack_ttl_expired_not_assumed_weth() public view {
        // LIVE: attestation residue may exist but isProven false after 7d TTL
        bool proven = IBoundGateT(BOUND_GATE).isProven(HOT);
        uint256 hotWeth = IERC20T(WETH).balanceOf(HOT);
        console2.log("isProven", proven);
        console2.log("hotWeth", hotWeth);
        // Doctrine: we do NOT hold ~380 WETH inventory
        assertLt(hotWeth, 1 ether, "hot must not be framed as holding engineer equity");
    }

    function test_layer_weth_poke_when_equity_engineered() public {
        // Simulate engineered equity (deal) — not claiming live inventory
        address keeper = makeAddr("keeper");

        vm.startPrank(HOT);
        CrownTakeWethIdle take =
            new CrownTakeWethIdle(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID, HOT, 350 ether, ASK);
        CrownZkLayeredLanding layer =
            new CrownZkLayeredLanding(BOUND_GATE, FLASH, CREDIT, AUTODRAW, USDC, HOT, LANDING, ASK);
        layer.setWethTake(address(take));
        IMorphoAuth(MORPHO).setAuthorization(address(take), true);
        deal(WETH, HOT, 380 ether);
        IERC20T(WETH).approve(address(take), type(uint256).max);
        vm.stopPrank();

        assertTrue(layer.wethReady(), "weth layer");
        // credit layer stays false without funded credit — poke uses WETH layer
        assertFalse(layer.creditReady(), "credit empty");

        uint256 land0 = IERC20T(USDC).balanceOf(LANDING);
        vm.prank(keeper);
        layer.poke();
        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - land0;
        assertEq(delta, ASK, "Landing ask");
        assertEq(layer.lastLayer(), 2);
    }
}
