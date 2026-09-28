// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownParallelSettlement} from "../src/china/CrownParallelSettlement.sol";
import {CrownRoyalCardNFC} from "../src/china/CrownRoyalCardNFC.sol";
import {CrownCIPSCorridor} from "../src/china/CrownCIPSCorridor.sol";
import {CrownStealthRouter} from "../src/china/CrownStealthRouter.sol";
import {CrownPayAdapter} from "../src/CrownPayAdapter.sol";
import {CrownOpenMoney} from "../src/CrownOpenMoney.sol";

contract MockTok {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a; balanceOf[to] += a; return true;
    }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        require(al >= a && balanceOf[f] >= a, "X");
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract MockBorders {
    bool public ok = true;
    function bordersSecure() external view returns (bool) { return ok; }
}

contract MockHunt {
    event Hunted(address token, uint256 assets);
    function hunt(address token, uint256 assets, address[] calldata, uint256[] calldata, bytes[] calldata, uint256)
        external
        payable
    {
        emit Hunted(token, assets);
    }
}

contract CnBuildsTest is Test {
    MockTok eusd;
    MockTok usdc;
    MockBorders borders;
    address king;
    address kar;
    address payer;
    address merc;
    address hot;

    function setUp() public {
        king = makeAddr("king");
        kar = makeAddr("kar");
        payer = makeAddr("payer");
        merc = makeAddr("merc");
        hot = makeAddr("hot");
        eusd = new MockTok();
        usdc = new MockTok();
        borders = new MockBorders();
        eusd.mint(payer, 1_000_000 ether);
        usdc.mint(king, 1_000_000e6);
    }

    function test_parallel_post_settle() public {
        CrownParallelSettlement par = new CrownParallelSettlement(address(eusd), king);
        vm.startPrank(king);
        par.setModules(address(borders), kar);
        vm.stopPrank();

        bytes32 id = keccak256("c1");
        vm.prank(kar);
        par.postClear(id, 8453, 137, payer, merc, 100 ether, keccak256("ref"));

        vm.prank(payer);
        eusd.approve(address(par), 100 ether);
        vm.prank(kar);
        par.settle(id);
        assertEq(eusd.balanceOf(merc), 100 ether);
    }

    function test_nfc_cache_settle() public {
        CrownPayAdapter pay = new CrownPayAdapter(address(eusd), king);
        CrownRoyalCardNFC nfc = new CrownRoyalCardNFC(address(eusd), king);
        vm.startPrank(king);
        pay.setMerchant(merc, true);
        pay.setPuller(address(nfc), true);
        nfc.setModules(address(pay), address(borders), kar);
        vm.stopPrank();

        bytes32 cid = keccak256("tap1");
        vm.prank(kar);
        nfc.cacheTap(cid, payer, merc, 50 ether, keccak256("sig"), 1 days);

        vm.prank(payer);
        eusd.approve(address(pay), 50 ether);
        vm.prank(kar);
        nfc.settle(cid);
        assertEq(eusd.balanceOf(merc), 50 ether);
        assertEq(nfc.pendingDebit(payer), 0);
    }

    function test_cips_invoice_eusd_usdc() public {
        CrownOpenMoney om = new CrownOpenMoney(address(eusd), address(usdc), king);
        CrownCIPSCorridor cips = new CrownCIPSCorridor(address(eusd), address(usdc), king);
        vm.startPrank(king);
        om.setMerchant(merc, true);
        cips.setModules(address(om), address(borders), king);
        usdc.approve(address(cips), 100_000e6);
        cips.fundUsdc(100_000e6);
        cips.openCorridor(keccak256("cor1"), keccak256("inv1"), merc, payer, hot, 10 ether);
        vm.stopPrank();

        vm.startPrank(payer);
        eusd.approve(address(cips), 10 ether);
        cips.captureEusd(keccak256("cor1"));
        vm.stopPrank();

        vm.prank(king);
        cips.settleUsdc(keccak256("cor1"));
        assertEq(usdc.balanceOf(hot), 10e6); // 10 eUSD → 10 USDC @ rate 1e6
        assertEq(eusd.balanceOf(address(cips)), 10 ether);
    }

    function test_stealth_commit_fire_sweep() public {
        MockHunt hunt = new MockHunt();
        MockTok weth = new MockTok();
        MockTok cbbtc = new MockTok();
        CrownStealthRouter stealth =
            new CrownStealthRouter(address(hunt), hot, address(weth), address(cbbtc), address(usdc), king);
        address bot = makeAddr("bot");
        vm.startPrank(king);
        stealth.setAttest(address(borders));
        stealth.setBot(bot, true);
        vm.stopPrank();

        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory datas = new bytes[](0);
        bytes32 salt = keccak256("s");
        uint256 assets = 1 ether;
        bytes32 commitHash = keccak256(abi.encode(address(weth), assets, targets, values, datas, uint256(0), salt));

        vm.prank(bot);
        stealth.commitIntent(commitHash);
        vm.prank(bot);
        stealth.fire(commitHash, address(weth), assets, targets, values, datas, 0, salt);
    }
}
