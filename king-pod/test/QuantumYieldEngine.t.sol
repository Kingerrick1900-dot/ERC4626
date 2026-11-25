// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownStarkSnarkBridge} from "../src/CrownStarkSnarkBridge.sol";
import {CrownPqRegistry} from "../src/CrownPqRegistry.sol";
import {CrownEasyTrigger} from "../src/CrownEasyTrigger.sol";
import {CrownQkdPilot} from "../src/CrownQkdPilot.sol";
import {CrownAmericaCapacity} from "../src/CrownAmericaCapacity.sol";
contract MockAttest {
    bool public ok = true;
    uint256 public epoch = 10;
    function bordersSecure() external view returns (bool) {
        return ok;
    }
    function commitPayrollRoot(bytes32, bool) external {}
    function attestLive(bytes32) external {
        epoch++;
    }
}

contract MockAllow {
    function check(address, bytes4) external pure {}
    function isAllowed(address, bytes4) external pure returns (bool) {
        return true;
    }
}

contract QuantumYieldEngineTest is Test {
    address hot = address(0xA11CE);
    MockAttest attest;
    MockAllow allow;

    function setUp() public {
        attest = new MockAttest();
        allow = new MockAllow();
    }

    function test_stark_snark_bind() public {
        CrownStarkSnarkBridge b = new CrownStarkSnarkBridge(address(attest), hot);
        vm.startPrank(hot);
        bytes32 root = keccak256("stark");
        b.commitStark(root, keccak256("pi"));
        b.bindToAttest(root);
        vm.stopPrank();
        assertEq(attest.epoch(), 11);
    }

    function test_pq_register_activate() public {
        CrownPqRegistry pq = new CrownPqRegistry(hot);
        vm.startPrank(hot);
        bytes32 id = pq.register(CrownPqRegistry.Alg.Dilithium3, keccak256("pub"), "king-root");
        pq.activate(id);
        vm.stopPrank();
        assertEq(pq.activeDilithium(), id);
    }

    function test_easy_trigger_deploy_with_nfc() public {
        EusdMock e = new EusdMock();
        CrownAmericaCapacity cap = new CrownAmericaCapacity(address(e), hot, 100_000_000_000_000 ether);
        vm.prank(hot);
        cap.setAttest(address(attest));
        CrownEasyTrigger easy = new CrownEasyTrigger(hot, hot);
        FakeTranche ft = new FakeTranche();
        vm.prank(hot);
        easy.wire(address(allow), address(attest), address(cap), address(ft));
        vm.startPrank(hot);
        bytes32 nfc = keccak256("tap");
        easy.submitNfcReceipt(nfc);
        uint256 d = easy.easyDeploy(100e6, nfc);
        assertEq(d, 100e6);
        vm.stopPrank();
    }

    function test_qkd_timeline_and_packet() public {
        CrownQkdPilot q = new CrownQkdPilot(address(attest), hot);
        vm.startPrank(hot);
        q.markT0(0);
        q.recordLoi("Conflux-LOI");
        q.openPilot();
        q.logPacket(keccak256("pkt"), keccak256("km"), "pilot-1");
        vm.stopPrank();
        assertEq(q.packetCount(), 1);
        assertGt(attest.epoch(), 10);
    }

    function test_100t_capacity_canMint_false_until_unlock() public {
        EusdMock e = new EusdMock();
        CrownAmericaCapacity cap = new CrownAmericaCapacity(address(e), hot, 100_000_000_000_000 ether);
        vm.prank(hot);
        cap.setAttest(address(attest));
        assertEq(cap.mintCapacity(), 100_000_000_000_000 ether);
        assertFalse(cap.canMint(1 ether));
        vm.prank(hot);
        cap.unlockTranche(1_000_000 ether, keccak256("nav"));
        assertTrue(cap.canMint(1_000_000 ether));
    }
}

contract EusdMock {
    function totalSupply() external pure returns (uint256) {
        return 0;
    }
}

contract FakeTranche {
    function deploy(uint256 usdcAmt) external pure returns (uint256) {
        return usdcAmt;
    }
    function remainingCap() external pure returns (uint256) {
        return type(uint256).max;
    }
}
