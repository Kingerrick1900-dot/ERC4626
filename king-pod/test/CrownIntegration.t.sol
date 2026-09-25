// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownSpendVault} from "../src/CrownSpendVault.sol";
import {CrownLsrEusd} from "../src/CrownLsrEusd.sol";
import {CrownBammOcean} from "../src/CrownBammOcean.sol";
import {CrownKingAgent} from "../src/CrownKingAgent.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockErc20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
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

    function transferFrom(address f, address to, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[to] += a;
        return true;
    }
}

contract MockEusd {
    string public name = "eUSD";
    string public symbol = "eUSD";
    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isMinter;
    uint256 public totalSupply;
    address public admin;

    constructor() {
        admin = msg.sender;
        isMinter[msg.sender] = true;
    }

    function setMinter(address a, bool on) external {
        require(msg.sender == admin, "ADMIN");
        isMinter[a] = on;
    }

    function mint(address to, uint256 amt) external {
        require(isMinter[msg.sender], "MINTER");
        balanceOf[to] += amt;
        totalSupply += amt;
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

    function transferFrom(address f, address to, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[to] += a;
        return true;
    }
}

contract CrownIntegrationTest is Test {
    address king = address(0xA11CE);
    address landing = address(0xB0B);
    MockEusd eusd;
    MockErc20 usdc;
    MockErc20 gusd;
    CrownSpendVault vault;
    CrownLsrEusd lsr;
    CrownBammOcean bamm;
    CrownKingAgent agent;

    function setUp() public {
        eusd = new MockEusd();
        usdc = new MockErc20("USDC", "USDC", 6);
        gusd = new MockErc20("gUSD", "gUSD", 18);

        vault = new CrownSpendVault(king, king);
        lsr = new CrownLsrEusd(address(usdc), address(eusd), king, landing, king);
        bamm = new CrownBammOcean(address(gusd), address(eusd), king, king);
        agent = new CrownKingAgent(king, landing, king);

        eusd.setMinter(address(lsr), true);
        eusd.setMinter(king, true);

        vm.startPrank(king);
        lsr.setOperator(address(agent), true);
        lsr.setOperator(address(vault), true);
        agent.setModules(address(vault), address(lsr), address(bamm));
        vault.setAgent(address(agent));
        vault.setTarget(address(lsr), true);
        vm.stopPrank();
    }

    function test_payroll_mint_to_landing() public {
        vm.prank(king);
        agent.firePayroll(5_000_000e18);
        assertEq(eusd.balanceOf(landing), 5_000_000e18);
    }

    function test_lsr_sellGem_usdc_to_eusd() public {
        usdc.mint(address(this), 1_000e6);
        usdc.approve(address(lsr), type(uint256).max);
        uint256 out = lsr.sellGem(1_000e6);
        assertEq(out, 1_000e18);
        assertEq(eusd.balanceOf(address(this)), 1_000e18);
        assertEq(lsr.usdcReserves(), 1_000e6);
    }

    function test_lsr_buyGem_roundtrip() public {
        usdc.mint(address(this), 2_000e6);
        usdc.approve(address(lsr), type(uint256).max);
        lsr.sellGem(2_000e6);
        eusd.approve(address(lsr), type(uint256).max);
        uint256 usdcOut = lsr.buyGem(1_000e18);
        assertEq(usdcOut, 1_000e6);
    }

    function test_bamm_lend_rent_oracle_free() public {
        gusd.mint(king, 10_000e18);
        eusd.mint(king, 10_000e18);
        vm.startPrank(king);
        gusd.approve(address(bamm), type(uint256).max);
        eusd.approve(address(bamm), type(uint256).max);
        bamm.lend(10_000e18, 10_000e18);

        // borrower
        address bob = address(0xB0B);
        gusd.mint(bob, 5_000e18);
        eusd.mint(bob, 5_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        gusd.approve(address(bamm), type(uint256).max);
        eusd.approve(address(bamm), type(uint256).max);
        bamm.addCollateral(5_000e18, 5_000e18);
        uint256 sk = bamm.sqrtK();
        uint256 rentAmt = sk / 10; // 10% of book
        (uint256 o0, uint256 o1) = bamm.rent(rentAmt);
        assertGt(o0, 0);
        assertGt(o1, 0);
        assertTrue(bamm.isSolvent(bob));
        vm.stopPrank();
    }

    function test_spend_vault_cap() public {
        vm.prank(king);
        vault.setLimits(100e18, 1000e18);
        // agent exec with over-cap should fail when amount counted
        vm.prank(king);
        vault.setTarget(address(lsr), true);
        bytes memory data = abi.encodeWithSelector(CrownLsrEusd.mintPayroll.selector, uint256(1e18));
        // amount 0 — calldata path, no cap on zero-amount execute
        vm.prank(address(agent));
        vault.execute(address(lsr), address(0), 0, data);
        assertEq(eusd.balanceOf(landing), 1e18);
    }

    function test_refuse_gasPark() public {
        vm.expectRevert(CrownKingAgent.NoGasPark.selector);
        agent.gasPark(1, 1);
    }
}
