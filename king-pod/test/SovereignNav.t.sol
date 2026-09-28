// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownSovereignBoard} from "../src/CrownSovereignBoard.sol";

contract MockAssets {
    uint256 public totalAssets;
    function set(uint256 v) external {
        totalAssets = v;
    }
}

contract MockTok {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
        totalSupply += a;
    }
}

contract MockCold {
    uint256 public balance;
    function set(uint256 v) external {
        balance = v;
    }
}

contract MockAttest {
    bool public bordersSecure = true;
    uint256 public epoch = 1;
    mapping(bytes32 => bool) public payrollRoots;
    mapping(uint256 => Att) public attestations;

    struct Att {
        uint256 epochId;
        uint256 nav;
        uint256 coldBal;
        bool navMet;
        bool reserveMet;
        bool payrollOk;
        bytes32 payloadHash;
        uint256 timestamp;
        bool snarkOk;
    }

    constructor() {
        attestations[1] = Att(1, 226e12, 1, true, true, true, keccak256("e1"), block.timestamp, false);
    }

    function commitPayrollRoot(bytes32 root, bool ok) external {
        payrollRoots[root] = ok;
    }

    function attestLive(bytes32 root) external returns (uint256) {
        require(payrollRoots[root], "ROOT");
        epoch += 1;
        bytes32 payload = keccak256(abi.encode(root, epoch));
        attestations[epoch] =
            Att(epoch, 226e12, 1, true, true, true, payload, block.timestamp, false);
        return epoch;
    }
}

contract SovereignNavTest is Test {
    MockAssets yrss;
    MockTok eusd;
    MockTok gusd;
    MockCold cold;
    MockAttest attest;
    address landing;
    address pool;
    address king;

    CrownSovereignBoard board;

    function setUp() public {
        yrss = new MockAssets();
        eusd = new MockTok();
        gusd = new MockTok();
        cold = new MockCold();
        attest = new MockAttest();
        landing = makeAddr("landing");
        pool = makeAddr("pool");
        king = makeAddr("king");

        yrss.set(226_000_000e6);
        eusd.mint(landing, 1_520_000_000 ether);
        eusd.mint(address(0xBEEF), 12_260_000_000 ether); // minted rest
        gusd.mint(pool, 5_000_000_000 ether);
        // eUSD ocean: mint to pool (also increases supply)
        eusd.mint(pool, 5_000_000_000 ether);
        cold.set(2_660_969);

        board = new CrownSovereignBoard(
            address(yrss), address(eusd), address(gusd), landing, pool, address(cold), address(attest), king
        );
    }

    function test_read_three_rails() public view {
        (CrownSovereignBoard.GoldRail memory g, CrownSovereignBoard.OceanRail memory o, CrownSovereignBoard.LandingRail memory l, bool borders)
        = board.readRails();
        assertEq(g.lockedGoldUsd6, 226_000_000e6);
        assertEq(g.idleRealEusd18, 1_520_000_000 ether);
        assertGt(g.mintedRealEusd18, 13_000_000_000 ether);
        assertEq(o.eusdOcean18, 5_000_000_000 ether);
        assertEq(o.gusdOcean18, 5_000_000_000 ether);
        assertEq(o.depth18, 10_000_000_000 ether);
        assertEq(l.idleEusd18, 1_520_000_000 ether);
        assertTrue(l.payrollLive);
        assertEq(l.coldBufferUsd6, 2_660_969);
        assertTrue(borders);
    }

    function test_publish_and_wire_no_capacity() public {
        vm.prank(king);
        bytes32 root = board.publish();
        assertTrue(root != bytes32(0));

        // HOT wires attest (simulated)
        attest.commitPayrollRoot(root, true);
        uint256 ep = attest.attestLive(root);

        vm.prank(king);
        board.recordWire(ep);

        (
            ,
            ,
            ,
            uint64 updatedAt,
            uint256 attestEpoch,
            bytes32 storedRoot,
            bytes32 payload,
            bool borders,
            bool wired
        ) = board.latest();
        assertEq(storedRoot, root);
        assertEq(attestEpoch, ep);
        assertTrue(wired);
        assertTrue(borders);
        assertTrue(payload != bytes32(0));
        assertGt(updatedAt, 0);
    }
}
