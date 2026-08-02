// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownMultiAssetPsm} from "../src/stack/CrownMultiAssetPsm.sol";
import {CrownElepanAsyncVault} from "../src/stack/CrownElepanAsyncVault.sol";

contract MockERC20MA {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public burnAsMinter = true;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address f, address t, uint256 amt) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        if (a != type(uint256).max) allowance[f][msg.sender] = a - amt;
        balanceOf[f] -= amt;
        balanceOf[t] += amt;
        return true;
    }

    function burn(address from, uint256 amt) external {
        balanceOf[from] -= amt;
        totalSupply -= amt;
    }

    function isMinter(address) external view returns (bool) {
        return burnAsMinter;
    }
}

contract MockFeed {
    uint8 public decimals = 8;
    int256 public answer;
    uint256 public updatedAt;
    bool public revertRound;

    constructor(int256 a) {
        answer = a;
        updatedAt = block.timestamp;
    }

    function set(int256 a, uint256 t) external {
        answer = a;
        updatedAt = t;
    }

    function setRevertRound(bool v) external {
        revertRound = v;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        if (revertRound) revert("NO_ROUND");
        return (1, answer, updatedAt, updatedAt, 1);
    }

    function latestAnswer() external view returns (int256) {
        return answer;
    }
}

contract MockWeth is MockERC20MA {
    constructor() MockERC20MA("WETH", "WETH", 18) {}

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    function withdraw(uint256 amt) external {
        balanceOf[msg.sender] -= amt;
        totalSupply -= amt;
        (bool ok,) = msg.sender.call{value: amt}("");
        require(ok, "WETH");
    }

    receive() external payable {}
}

contract MultiAssetPsmTest is Test {
    MockERC20MA eusd;
    MockERC20MA usdc;
    MockERC20MA usdt;
    MockERC20MA dai;
    MockERC20MA eurc;
    MockWeth weth;

    MockFeed feedUsdc;
    MockFeed feedUsdt;
    MockFeed feedDai;
    MockFeed feedEth;
    MockFeed feedEurc;

    CrownMultiAssetPsm psm;
    address landing = address(0x1A11d);
    address user = address(0xA11CE);

    function setUp() public {
        eusd = new MockERC20MA("eUSD", "eUSD", 18);
        usdc = new MockERC20MA("USDC", "USDC", 6);
        usdt = new MockERC20MA("USDT", "USDT", 6);
        dai = new MockERC20MA("DAI", "DAI", 18);
        eurc = new MockERC20MA("EURC", "EURC", 6);
        weth = new MockWeth();

        feedUsdc = new MockFeed(1e8);
        feedUsdt = new MockFeed(1e8);
        feedDai = new MockFeed(1e8);
        feedEth = new MockFeed(3000e8);
        feedEurc = new MockFeed(1.08e8); // ~$1.08
        feedEurc.setRevertRound(true); // capped adapter path

        psm = new CrownMultiAssetPsm(address(eusd), address(usdc), landing, address(weth), address(this));

        psm.listAsset(address(usdc), address(feedUsdc), 6, false);
        psm.listAsset(address(usdt), address(feedUsdt), 6, false);
        psm.listAsset(address(dai), address(feedDai), 18, false);
        psm.listAsset(address(weth), address(feedEth), 18, false);
        psm.listAsset(address(eurc), address(feedEurc), 6, true);

        usdc.mint(address(psm), 10_000e6);
        usdt.mint(address(psm), 10_000e6);
        dai.mint(address(psm), 10_000e18);
        eurc.mint(address(psm), 10_000e6);
        weth.mint(address(psm), 10e18);
        // fund WETH contract for unwrap
        vm.deal(address(weth), 100e18);

        eusd.mint(user, 10_000e18);
        vm.warp(1_700_000_000);
        feedUsdc.set(1e8, block.timestamp);
        feedUsdt.set(1e8, block.timestamp);
        feedDai.set(1e8, block.timestamp);
        feedEth.set(3000e8, block.timestamp);
        feedEurc.set(1.08e8, block.timestamp);
    }

    function test_usdc_hint_and_reserve() public view {
        assertEq(psm.usdc(), address(usdc));
        assertEq(psm.usdcReserve(), 10_000e6);
        assertEq(psm.assetCount(), 5);
    }

    function test_redeemUsdc_parity() public {
        vm.startPrank(user);
        eusd.approve(address(psm), 100e18);
        uint256 out = psm.redeemUsdc(100e18, user);
        vm.stopPrank();
        assertEq(out, 100e6);
        assertEq(usdc.balanceOf(user), 100e6);
    }

    function test_redeemUsdt() public {
        vm.startPrank(user);
        eusd.approve(address(psm), 50e18);
        uint256 out = psm.redeemAsset(address(usdt), 50e18, user);
        vm.stopPrank();
        assertEq(out, 50e6);
    }

    function test_redeemDai() public {
        vm.startPrank(user);
        eusd.approve(address(psm), 25e18);
        uint256 out = psm.redeemAsset(address(dai), 25e18, user);
        vm.stopPrank();
        assertEq(out, 25e18);
    }

    function test_redeemWeth() public {
        vm.startPrank(user);
        eusd.approve(address(psm), 3000e18); // $3000 → 1 WETH
        uint256 out = psm.redeemAsset(address(weth), 3000e18, user);
        vm.stopPrank();
        assertEq(out, 1e18);
    }

    function test_redeemEth_unwrap() public {
        uint256 before = user.balance;
        vm.startPrank(user);
        eusd.approve(address(psm), 3000e18);
        uint256 out = psm.redeemEth(3000e18, user);
        vm.stopPrank();
        assertEq(out, 1e18);
        assertEq(user.balance - before, 1e18);
    }

    function test_redeemEurc_latestAnswer() public {
        // $100 eUSD / $1.08 ≈ 92.592592 EURC (6dp)
        vm.startPrank(user);
        eusd.approve(address(psm), 100e18);
        uint256 out = psm.redeemAsset(address(eurc), 100e18, user);
        vm.stopPrank();
        assertEq(out, (uint256(100e8) * 1e6) / uint256(1.08e8));
    }

    function test_7540_vault_wraps_unchanged() public {
        // Same CrownElepanAsyncVault bytecode against multi-asset PSM (USDC path only).
        CrownElepanAsyncVault vault = new CrownElepanAsyncVault(address(psm), address(this));
        assertEq(address(vault.usdc()), address(usdc));
        assertEq(address(vault.asset()), address(eusd));

        vm.startPrank(user);
        eusd.approve(address(vault), 10e18);
        uint256 id = vault.requestRedeem(10e18, user, user);
        vm.stopPrank();

        uint256 usdcOut = vault.fulfillRedeem(id);
        assertEq(usdcOut, 10e6);

        vm.prank(user);
        assertEq(vault.claimRedeem(id, user), 10e6);
        assertEq(usdc.balanceOf(user), 10e6);
    }

    function test_stale_feed_reverts() public {
        feedUsdt.set(1e8, block.timestamp - 2 days);
        vm.startPrank(user);
        eusd.approve(address(psm), 1e18);
        vm.expectRevert(CrownMultiAssetPsm.Stale.selector);
        psm.redeemAsset(address(usdt), 1e18, user);
        vm.stopPrank();
    }
}
