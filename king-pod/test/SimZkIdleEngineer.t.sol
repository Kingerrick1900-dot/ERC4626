// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownZkIdleEngineer} from "../src/zk/CrownZkIdleEngineer.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

interface IMorphoT {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IZkT {
    function isProven(address) external view returns (bool);
}

interface IYrssT {
    function maxWithdraw(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @notice Fork: ZK idle ingress — King into IDLE via flash+onBehalf, SOV-matched repay.
contract SimZkIdleEngineer is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ZK = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant SOV_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant LIVE_GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant IDLE = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    uint256 constant AMT = 1_100_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", vm.envOr("BASE_RPC", string(""))));
    }

    function test_zk_idle_sov_match_1_1m() public {
        assertTrue(IZkT(ZK).isProven(HOT), "ZK");

        uint256 assetsBefore = IYrssT(YRSS).totalAssets();
        (uint256 idleBefore,,) = IMorphoT(MORPHO).position(IDLE, YRSS);
        assertEq(idleBefore, 0, "start empty idle");

        CrownGateV2 gate = CrownGateV2(LIVE_GATE);
        (, uint128 gBor, uint128 gColl) = IMorphoT(MORPHO).position(SOV, address(gate));
        assertGt(uint256(gColl), 0, "gate has RSS");
        assertEq(uint256(gBor), 0, "gate clean before match");

        vm.startPrank(HOT);
        CrownZkIdleEngineer eng =
            new CrownZkIdleEngineer(MORPHO, USDC, YRSS, ZK, address(gate), HOT, HOT);
        gate.setOperator(address(eng), true);
        eng.engineerIdleSovMatch(AMT);
        vm.stopPrank();

        (uint256 idleShares,,) = IMorphoT(MORPHO).position(IDLE, YRSS);
        (uint256 sovShares,,) = IMorphoT(MORPHO).position(SOV, YRSS);
        (, uint128 gBor2,) = IMorphoT(MORPHO).position(SOV, address(gate));
        uint256 assetsAfter = IYrssT(YRSS).totalAssets();
        uint256 maxW = IYrssT(YRSS).maxWithdraw(HOT);

        assertGt(idleShares, 0, "KING IN IDLE");
        assertGt(sovShares, 0, "yRSS on SOV");
        assertGt(uint256(gBor2), 0, "gate debt funds flash repay");
        assertGe(assetsAfter, assetsBefore + AMT - 1e6, "TVL up");
        assertGe(maxW, AMT, "maxWithdraw opens on idle");

        console2.log("IDLE shares yRSS", idleShares);
        console2.log("SOV shares yRSS", sovShares);
        console2.log("gateBorShares", uint256(gBor2));
        console2.log("maxWithdraw", maxW);
        console2.log("totalAssets after", assetsAfter);
        console2.log("KING_IN_IDLE", uint256(1));
        console2.log("ZK_SHIELD", uint256(1));
    }

    function test_reverts_without_zk() public {
        // warp past proof TTL if needed — use wrong gate via fresh deploy with mock
        // Live proof is true; deploy engineer pointing at address(0) pattern: use empty contract
        MockZkOff off = new MockZkOff();
        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        CrownGateV2 g = new CrownGateV2(HOT, address(off), mp);
        CrownZkIdleEngineer eng = new CrownZkIdleEngineer(MORPHO, USDC, YRSS, address(off), address(g), HOT, HOT);
        vm.prank(HOT);
        vm.expectRevert(CrownZkIdleEngineer.NotProven.selector);
        eng.engineerIdleSovMatch(1e6);
    }
}

contract MockZkOff {
    function isProven(address) external pure returns (bool) {
        return false;
    }
}
