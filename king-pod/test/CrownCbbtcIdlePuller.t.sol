// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownCbbtcIdlePuller} from "../src/CrownCbbtcIdlePuller.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20Cb {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amt, "ALLOW");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        require(balanceOf[from] >= amt, "BAL");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockOracleCb {
    uint256 public price = 791526871656500000000000000000000000000; // ~$79,152.68 / BTC Morpho scale

    function set(uint256 p) external {
        price = p;
    }
}

contract MockMorphoCb {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    address public flashCaller;
    mapping(bytes32 => uint128) public supplyAssets;
    mapping(bytes32 => uint128) public borrowAssets;
    mapping(bytes32 => mapping(address => uint256)) public collOf;
    mapping(bytes32 => mapping(address => uint256)) public borrowOf;

    function setFlashCaller(address a) external {
        flashCaller = a;
    }

    function setBook(bytes32 id, uint128 s, uint128 b) external {
        supplyAssets[id] = s;
        borrowAssets[id] = b;
    }

    function flashLoan(address token, uint256 assets, bytes calldata) external {
        MockERC20Cb(token).mint(msg.sender, assets);
        CrownCbbtcIdlePuller(msg.sender).onMorphoFlashLoan(assets, "");
        // repay: burn from caller
        require(MockERC20Cb(token).balanceOf(msg.sender) >= assets, "REPAY");
        MockERC20Cb(token).transferFrom(msg.sender, address(this), assets);
    }

    function supply(MarketParams memory mp, uint256 assets, uint256, address, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        supplyAssets[id] += uint128(assets);
        return (assets, assets);
    }

    function supplyCollateral(MarketParams memory mp, uint256 assets, address onBehalf, bytes memory) external {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.collateralToken).transferFrom(msg.sender, address(this), assets);
        collOf[id][onBehalf] += assets;
    }

    function borrow(MarketParams memory mp, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        require(supplyAssets[id] >= borrowAssets[id] + assets, "LIQ");
        borrowAssets[id] += uint128(assets);
        borrowOf[id][onBehalf] += assets;
        IERC20(mp.loanToken).transfer(receiver, assets);
        return (assets, assets);
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        return (supplyAssets[id], 0, borrowAssets[id], 0, 0, 0);
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128) {
        return (0, uint128(borrowOf[id][user]), uint128(collOf[id][user]));
    }
}

contract CrownCbbtcIdlePullerTest is Test {
    address constant KING = address(0x6708);
    address constant RSS = address(0x1212);
    address constant IRM = address(0xCAFE);

    MockERC20Cb usdc;
    MockERC20Cb cbbtc;
    MockOracleCb oracle;
    MockMorphoCb morpho;
    CrownCbbtcIdlePuller puller;
    bytes32 parkId;
    bytes32 cbId;

    function setUp() public {
        usdc = new MockERC20Cb();
        cbbtc = new MockERC20Cb();
        oracle = new MockOracleCb();
        morpho = new MockMorphoCb();
        puller = new CrownCbbtcIdlePuller(
            address(morpho), address(usdc), address(cbbtc), KING, address(0), uint24(500), KING
        );
        parkId = keccak256(abi.encode(address(usdc), RSS, address(oracle), IRM, uint256(77e16)));
        cbId = keccak256(abi.encode(address(usdc), address(cbbtc), address(oracle), IRM, uint256(86e16)));
        vm.prank(KING);
        puller.setMarkets(RSS, address(oracle), address(oracle), IRM, 77e16, 86e16, parkId, cbId);
        // Deep cbBTC/USDC book — $200M idle
        morpho.setBook(cbId, 400_000_000e6, 200_000_000e6);
        morpho.setBook(parkId, 1_000e6, 1_000e6); // $0 idle start (dust matched)
        // Seed morpho with USDC for borrow payouts in mock (borrow transfers from morpho)
        usdc.mint(address(morpho), 500_000_000e6);
        // King holds ~25 BTC
        cbbtc.mint(KING, 25e8);
        vm.prank(KING);
        cbbtc.approve(address(puller), type(uint256).max);
        // Puller must approve morpho for repay path — mock pulls usdc back via transferFrom
        vm.prank(address(puller));
        usdc.approve(address(morpho), type(uint256).max);
    }

    function test_quote_coll_for_1_5m() public view {
        uint256 coll = puller.quoteCollForIdle(1_500_000e6);
        assertGt(coll, 22e8);
        assertLt(coll, 24e8);
        uint256 maxIdle = puller.quoteMaxIdle(coll);
        assertGe(maxIdle, 1_500_000e6);
    }

    function test_pull_millions_engineers_park_idle() public {
        uint256 before = puller.idlePark();
        vm.prank(KING);
        uint256 after_ = puller.pullMillions();
        assertGe(after_, before + 1_500_000e6 - 1);
        assertEq(puller.totalIdlePulled(), 1_500_000e6);
        assertGe(puller.totalCbbtcPosted(), 22e8);
        assertGe(puller.minIdleBuffer(), 1_500_000e6);
    }

    function test_gasPark_blocked() public {
        vm.expectRevert(CrownCbbtcIdlePuller.NoBorrow.selector);
        puller.gasPark(1, 0);
    }

    function test_wealth_board() public view {
        (uint256 parkIdle, uint256 bookIdle, uint256 ask, uint256 collForAsk, uint256 kingCb, uint256 maxNow) =
            puller.wealthBoard();
        assertEq(ask, 1_500_000e6);
        assertGt(collForAsk, 0);
        assertEq(kingCb, 25e8);
        assertGt(maxNow, ask);
        assertEq(parkIdle, 0);
        assertEq(bookIdle, 200_000_000e6);
    }
}
