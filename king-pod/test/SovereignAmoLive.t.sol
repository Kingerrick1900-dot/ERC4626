// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownSovereignExit} from "../src/CrownSovereignExit.sol";

/// @notice Safety proofs against LIVE Base mainnet deployment (fork-only).
interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoPosL {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IBoundGateL {
    function isProven(address) external view returns (bool);
    function proofTtl() external view returns (uint256);
    function attestations(address) external view returns (uint256, uint256, bool);
}

contract SovereignAmoLiveForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;

    address constant AMO = 0x151C947B813400fE78EE176843F2d666c07422eA;
    address constant EXIT = 0x937Ba9eA3288781851E19Df50D33b800b10F064b;
    bytes32 constant MID = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;

    CrownSovereignAmo amo;
    CrownSovereignExit exiter;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        amo = CrownSovereignAmo(AMO);
        exiter = CrownSovereignExit(EXIT);
    }

    function test_live_exit_full_unwind() public {
        uint256 land0 = IERC20L(EUSD).balanceOf(LANDING);
        uint256 rss0 = IERC20L(RSS).balanceOf(HOT);

        // Accrued interest > borrowed principal; king must hold repay buffer on live exit.
        deal(EUSD, HOT, IERC20L(EUSD).balanceOf(HOT) + 500 ether);

        vm.startPrank(HOT);
        IERC20L(EUSD).approve(EXIT, type(uint256).max);
        exiter.exitFull();
        vm.stopPrank();

        assertGe(IERC20L(EUSD).balanceOf(LANDING), land0, "landing recall");
        assertGe(IERC20L(RSS).balanceOf(HOT), rss0, "rss returned");

        (, uint128 bor, uint128 coll) = IMorphoPosL(MORPHO).position(MID, HOT);
        (uint256 sup,,) = IMorphoPosL(MORPHO).position(MID, LANDING);
        assertEq(bor, 0, "debt dust");
        assertEq(coll, 0, "coll dust");
        assertEq(sup, 0, "supply dust");

        console2.log("landing eUSD after live exit", IERC20L(EUSD).balanceOf(LANDING));
    }

    function test_live_gate_armed_and_proven() public view {
        IBoundGateL g = IBoundGateL(GATE);
        assertTrue(g.isProven(HOT), "pack should be proven after refresh");
        assertTrue(amo.requireGate(), "gate should be re-armed");
        assertTrue(amo.packReady(), "packReady with fresh proof");
        assertEq(g.proofTtl(), 7 days, "expected 7d proof TTL");
    }

    function test_live_gate_blocks_borrow_without_proof() public {
        // Simulate expired proof: re-arm stays on, borrow must revert.
        IBoundGateL g = IBoundGateL(GATE);
        (, uint256 attestedAt,) = g.attestations(HOT);
        vm.warp(attestedAt + g.proofTtl() + 1);
        assertFalse(g.isProven(HOT), "warp past TTL");
        assertFalse(amo.packReady(), "expired => not ready");

        vm.startPrank(HOT);
        vm.expectRevert(CrownSovereignAmo.GateMiss.selector);
        amo.borrowEusd(1e18, HOT);
        vm.stopPrank();
    }
}
