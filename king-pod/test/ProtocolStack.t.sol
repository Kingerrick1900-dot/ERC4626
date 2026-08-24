// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "../src/lib/Core.sol";
import {CrownElepanAsyncVault} from "../src/stack/CrownElepanAsyncVault.sol";
import {CrownPsmIntentSettlement} from "../src/stack/CrownPsmIntentSettlement.sol";
import {CrownEle77PoRFeed, CrownGoldCdpPoRFeed} from "../src/stack/CrownChainlinkPoR.sol";
import {CrownEusdV4Hook, PoolKey} from "../src/stack/CrownEusdV4Hook.sol";
import {CrownCrossChainSettlement} from "../src/stack/CrownCrossChainSettlement.sol";
import {
    GaslessCrossChainOrder
} from "../src/stack/interfaces/IERC7683.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

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

    function isMinter(address) external pure returns (bool) {
        return true;
    }
}

contract MockPsm {
    MockERC20 public eusd;
    MockERC20 public usdc;
    MockERC20 public kxau;
    address public oracle;
    address public landing;

    constructor(MockERC20 e, MockERC20 u, MockERC20 k) {
        eusd = e;
        usdc = u;
        kxau = k;
        landing = address(1);
        oracle = address(2);
    }

    function redeemUsdc(uint256 eusdAmt, address to) external returns (uint256 usdcOut) {
        usdcOut = eusdAmt / 1e12;
        eusd.transferFrom(msg.sender, address(this), eusdAmt);
        eusd.burn(address(this), eusdAmt);
        usdc.transfer(to, usdcOut);
    }

    function usdcReserve() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function goldReserveUsd6() external pure returns (uint256) {
        return 0;
    }

    function quoteKxau(uint256) external pure returns (uint256) {
        return 0;
    }

    function redeemKxau(uint256, address) external pure returns (uint256) {
        return 0;
    }

    function seedUsdc(uint256) external {}
    function seedKxau(uint256) external {}
}

contract MockMorpho {
    uint128 public supply;
    uint128 public borrow;

    function set(uint128 s, uint128 b) external {
        supply = s;
        borrow = b;
    }

    function market(bytes32)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128)
    {
        return (supply, 0, borrow, 0, uint128(block.timestamp), 0);
    }

    function position(bytes32, address) external pure returns (uint256, uint128, uint128) {
        return (0, 0, 1e8);
    }
}

contract MockGoldCdp {
    uint256 public coll = 100001e8 / 100; // match live scale roughly
    uint256 public debt = 645167741935483870967741;
    address public gold = address(0x60Cd);
    address public oracle;

    constructor(address oracle_) {
        oracle = oracle_;
        coll = 10000100000000;
    }

    function healthFactor() external pure returns (uint256) {
        return 155e16;
    }
}

contract MockOracle {
    function price() external pure returns (uint256) {
        return 1e35; // $10
    }
}

contract ProtocolStackTest is Test {
    MockERC20 eusd;
    MockERC20 usdc;
    MockERC20 kxau;
    MockPsm psm;
    CrownElepanAsyncVault vault;
    CrownPsmIntentSettlement settlement;

    address user = address(0xA11CE);
    address solver = address(0x501BE);

    function setUp() public {
        eusd = new MockERC20("eUSD", "eUSD", 18);
        usdc = new MockERC20("USDC", "USDC", 6);
        kxau = new MockERC20("kXAU", "kXAU", 8);
        psm = new MockPsm(eusd, usdc, kxau);
        usdc.mint(address(psm), 1_000_000e6);
        vault = new CrownElepanAsyncVault(address(psm), address(this));
        settlement = new CrownPsmIntentSettlement(address(vault), address(usdc), 534352, 8453, address(this));
        vault.setOperator(address(settlement), true);

        eusd.mint(user, 1000e18);
        usdc.mint(solver, 1000e6);
    }

    function test_7540_request_fulfill_claim() public {
        vm.startPrank(user);
        eusd.approve(address(vault), 100e18);
        uint256 id = vault.requestRedeem(100e18, user, user);
        vm.stopPrank();

        vault.setOperator(user, true); // owner path: vault owner can fulfill
        // Actually fulfill requires operator of controller(=user) or vault owner
        uint256 out = vault.fulfillRedeem(id);
        assertEq(out, 100e6);

        vm.prank(user);
        uint256 claimed = vault.claimRedeem(id, user);
        assertEq(claimed, 100e6);
        assertEq(usdc.balanceOf(user), 100e6);
    }

    function test_7683_open_fill_settle() public {
        // User opens via settlement — settlement must be able to requestRedeem as owner of pulled eUSD
        vm.startPrank(user);
        eusd.approve(address(settlement), 50e18);
        GaslessCrossChainOrder memory order = GaslessCrossChainOrder({
            originSettler: address(settlement),
            user: user,
            nonce: 0,
            originChainId: 534352,
            openDeadline: uint32(block.timestamp + 1 days),
            fillDeadline: uint32(block.timestamp + 1 days),
            orderDataType: settlement.ORDER_TYPE_PSM_REDEEM(),
            orderData: abi.encode(user, uint256(50e18), user, uint256(50e6))
        });
        settlement.open(order, "", "");
        vm.stopPrank();

        bytes32 id = settlement.orderIdOf(order);

        vm.startPrank(solver);
        usdc.approve(address(settlement), 50e6);
        settlement.fill(id, abi.encode(id), abi.encode(uint256(50e6)));
        vm.stopPrank();

        // settle on Scroll side — reclaim PSM USDC to filler
        uint256 before = usdc.balanceOf(solver);
        // refill solver spent 50e6 to user; settle returns PSM USDC to filler
        settlement.settle(id);
        assertEq(usdc.balanceOf(solver), before + 50e6);
    }

    function test_por_ele77_and_gold() public {
        MockMorpho m = new MockMorpho();
        m.set(16_500_000e6, 16_500_000e6);
        CrownEle77PoRFeed elePor = new CrownEle77PoRFeed(
            address(m), bytes32(uint256(1)), address(0), address(this)
        );
        (, int256 ans,,,) = elePor.latestRoundData();
        assertEq(uint256(ans), 16_500_000e6);

        MockOracle o = new MockOracle();
        MockGoldCdp cdp = new MockGoldCdp(address(o));
        CrownGoldCdpPoRFeed gPor = new CrownGoldCdpPoRFeed(address(cdp), address(this));
        (, int256 gans,,,) = gPor.latestRoundData();
        // coll 100001e8 * 1e35 / 1e36 = 100001e7 = 1_000_010_000_000
        assertEq(uint256(gans), (uint256(10000100000000) * 1e35) / 1e36);
    }

    function test_v4_hook_reference_price() public {
        CrownEusdV4Hook hook = new CrownEusdV4Hook(address(this), address(eusd), address(usdc), address(this));
        PoolKey memory key = PoolKey(address(usdc), address(eusd), 500, 10, address(hook));
        // sqrtPriceX96 for 1:1 with decimal adjust is complex — push observation directly
        bytes32 id = keccak256(abi.encode(key));
        // Register key via afterInitialize as poolManager(=this)
        hook.afterInitialize(address(0), key, uint160(2 ** 96), 0);
        uint256 px = hook.getReferencePrice(id);
        // At sqrtPrice = 2^96, ratio=1. With usdc/eusd ordering → WAD scale path
        assertGt(px, 0);
    }

    function test_ccip_lz_settlement_wire() public {
        CrownCrossChainSettlement baseS =
            new CrownCrossChainSettlement(address(eusd), address(this));
        CrownCrossChainSettlement scrollS =
            new CrownCrossChainSettlement(address(eusd), address(this));
        baseS.setPeer(address(scrollS), 1, 1);
        scrollS.setPeer(address(baseS), 1, 1);
        baseS.setEndpoints(address(0), address(0), address(0xB), address(0));
        scrollS.setEndpoints(address(0), address(0), address(0), address(0x5));
        assertEq(uint8(baseS.defaultRail()), uint8(CrownCrossChainSettlement.Rail.Link));
    }
}
