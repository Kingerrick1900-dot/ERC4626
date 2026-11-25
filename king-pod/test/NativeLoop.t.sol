// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownCuratorNative} from "../src/CrownCuratorNative.sol";
import {CrownExitNative} from "../src/CrownExitNative.sol";
import {CrownEusdSleeve} from "../src/CrownEusdSleeve.sol";
import {CrownPqRegistry} from "../src/CrownPqRegistry.sol";

contract MockEusd {
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public isMinter;
    mapping(address => mapping(address => uint256)) public allowance;
    function setMinter(address a, bool v) external {
        isMinter[a] = v;
    }
    function mint(address to, uint256 amt) external {
        require(isMinter[msg.sender], "M");
        balanceOf[to] += amt;
    }
    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }
    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract MockAtt {
    function bordersSecure() external pure returns (bool) {
        return true;
    }
}

contract MockCap {
    uint256 public unlocked;
    function canMint(uint256 a) external view returns (bool) {
        return a <= unlocked;
    }
    function unlock(uint256 a) external {
        unlocked += a;
    }
}

contract NativeLoopTest is Test {
    address hot = address(0xA11CE);
    MockEusd eusd;
    MockAtt attest;
    MockCap cap;
    CrownPqRegistry pq;
    CrownCuratorNative curator;
    CrownExitNative exitV;
    address usdc = address(0xBEEF);
    address btc = address(0xB7C);
    address weth = address(0xEEE);

    function setUp() public {
        eusd = new MockEusd();
        attest = new MockAtt();
        cap = new MockCap();
        pq = new CrownPqRegistry(hot);
        curator = new CrownCuratorNative(address(eusd), hot, hot);
        exitV = new CrownExitNative(address(eusd), hot, usdc, btc, weth, hot);
        CrownEusdSleeve p = new CrownEusdSleeve(address(eusd), hot, "P");
        CrownEusdSleeve a = new CrownEusdSleeve(address(eusd), hot, "A");
        vm.startPrank(hot);
        bytes32 id = pq.register(CrownPqRegistry.Alg.Dilithium3, keccak256("pub"), "k");
        pq.activate(id);
        curator.setArmor(address(attest), address(pq), address(cap));
        curator.setStrategies(address(0), address(p), address(a));
        curator.setArmed(true);
        eusd.setMinter(address(curator), true);
        exitV.setArmor(address(attest), address(pq));
        cap.unlock(200_000_000 ether);
        vm.stopPrank();
    }

    function test_nfc_mint_200m() public {
        vm.prank(hot);
        curator.nfcMintAndDeposit(200_000_000 ether, keccak256("nfc1"), bytes32(0));
        assertEq(curator.totalMinted(), 200_000_000 ether);
        assertEq(eusd.balanceOf(address(curator)), 200_000_000 ether);
    }

    function test_allocate_sleeves() public {
        vm.startPrank(hot);
        curator.nfcMintAndDeposit(100 ether, keccak256("nfc2"), bytes32(0));
        curator.allocate();
        vm.stopPrank();
        assertLt(eusd.balanceOf(address(curator)), 100 ether);
    }

    function test_exit_usdc_from_inventory() public {
        // mock USDC token as MockEusd clone behavior — use deal-like mint via mock
        MockEusd u = new MockEusd();
        // redeploy exit with mock usdc
        CrownExitNative ex = new CrownExitNative(address(eusd), hot, address(u), btc, weth, hot);
        vm.startPrank(hot);
        ex.setArmor(address(attest), address(pq));
        u.setMinter(hot, true);
        u.mint(hot, 1_000e6);
        u.approve(address(ex), 1_000e6);
        ex.fundInventory(address(u), 1_000e6);
        eusd.setMinter(hot, true);
        eusd.mint(hot, 1000 ether);
        eusd.approve(address(ex), 1000 ether);
        uint256 out = ex.exit(1000 ether, address(u), 1000e6, keccak256("nfc-exit"));
        assertEq(out, 1000e6);
        assertEq(u.balanceOf(hot), 1000e6);
        vm.stopPrank();
    }
}
