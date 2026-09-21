// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownDeedPeel} from "../src/CrownDeedPeel.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20D {
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

contract MockMorphoD {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    mapping(bytes32 => uint128) public supplyAssets;
    mapping(bytes32 => uint128) public borrowAssets;
    mapping(bytes32 => mapping(address => uint128)) public borShares;

    function setBook(bytes32 id, uint128 s, uint128 b) external {
        supplyAssets[id] = s;
        borrowAssets[id] = b;
    }

    function setBorrow(bytes32 id, address user, uint128 shares) external {
        borShares[id][user] = shares;
    }

    function repay(MarketParams memory mp, uint256 assets, uint256, address onBehalf, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        require(borrowAssets[id] >= assets, "B");
        borrowAssets[id] -= uint128(assets);
        if (borShares[id][onBehalf] >= assets) borShares[id][onBehalf] -= uint128(assets);
        else borShares[id][onBehalf] = 0;
        return (assets, assets);
    }

    function accrueInterest(MarketParams memory) external pure {}

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        return (supplyAssets[id], 0, borrowAssets[id], borrowAssets[id], 0, 0);
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128) {
        return (0, borShares[id][user], 0);
    }
}

contract YrssOk {
    MockERC20D public usdc;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) internal _assets;

    constructor(MockERC20D u) {
        usdc = u;
    }

    function seed(address king, uint256 shares, uint256 assets, uint256 idleUsdc) external {
        balanceOf[king] = shares;
        _assets[king] = assets;
        usdc.mint(address(this), idleUsdc);
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function convertToAssets(uint256) external view returns (uint256) {
        return _assets[address(0x6708)];
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        uint256 bal = usdc.balanceOf(address(this));
        uint256 claim = _assets[owner];
        return bal < claim ? bal : claim;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        require(allowance[owner][msg.sender] == type(uint256).max || allowance[owner][msg.sender] >= assets, "ALLOW");
        require(assets <= this.maxWithdraw(owner), "MAX");
        _assets[owner] -= assets;
        usdc.transfer(receiver, assets);
        return assets;
    }
}

contract CrownDeedPeelTest is Test {
    address constant KING = address(0x6708);
    address constant LANDING = address(0x5Adc);
    address constant RSS = address(0x1212);
    address constant ORACLE = address(0xBEEF);
    address constant IRM = address(0xCAFE);

    MockERC20D usdc;
    MockMorphoD morpho;
    YrssOk yrss;
    CrownDeedPeel peel;
    bytes32 parkId;

    function setUp() public {
        usdc = new MockERC20D();
        morpho = new MockMorphoD();
        yrss = new YrssOk(usdc);
        peel = new CrownDeedPeel(address(morpho), address(usdc), address(yrss), KING, LANDING, KING);
        parkId = keccak256(abi.encode(address(usdc), RSS, ORACLE, IRM, uint256(77e16)));
        vm.prank(KING);
        peel.setMarket(RSS, ORACLE, IRM, 77e16, parkId);

        morpho.setBook(parkId, 2_000_000e6, 2_000_000e6 - 1_514_572);
        morpho.setBorrow(parkId, KING, uint128(2_000_000e6 - 1_514_572));
        yrss.seed(KING, 1e18, 1_010_000e6, 1_514_572);
        vm.prank(KING);
        yrss.approve(address(peel), type(uint256).max);
    }

    function test_board_and_peel_dust() public {
        (uint256 deed, uint256 peelable, uint256 parkIdle,, uint256 util,) = peel.board();
        assertEq(deed, 1_010_000e6);
        assertEq(peelable, 1_514_572);
        assertEq(parkIdle, 1_514_572);
        assertGt(util, 9_900);

        vm.prank(KING);
        uint256 got = peel.peelDust();
        assertEq(got, 1_514_572);
        assertEq(usdc.balanceOf(LANDING), 1_514_572);
    }

    function test_unmatch_and_peel() public {
        usdc.mint(KING, 1_010_000e6);
        usdc.mint(address(yrss), 1_010_000e6); // morpho idle → vault liquidity (mock)
        vm.startPrank(KING);
        usdc.approve(address(peel), type(uint256).max);
        (uint256 idleAfter, uint256 peeled) = peel.unmatchAndPeel(1_010_000e6, 0);
        vm.stopPrank();
        assertGe(idleAfter, 1_010_000e6);
        assertEq(peeled, 1_010_000e6);
        assertEq(usdc.balanceOf(LANDING), 1_010_000e6);
    }

    function test_gasPark_blocked() public {
        vm.expectRevert(CrownDeedPeel.NoBorrow.selector);
        peel.gasPark(1, 0);
    }
}
