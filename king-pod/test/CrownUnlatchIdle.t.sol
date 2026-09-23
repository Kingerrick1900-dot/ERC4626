// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownUnlatchIdle} from "../src/CrownUnlatchIdle.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20U {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public immutable decimals = 6;

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

contract MockMorphoU {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Mkt {
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 totalBorrowAssets;
        uint128 totalBorrowShares;
    }

    mapping(bytes32 => Mkt) public markets;
    mapping(bytes32 => mapping(address => uint128)) public borrowSharesOf;
    uint256 constant SHARE_SCALE = 1e6;

    function supply(MarketParams memory mp, uint256 assets, uint256, address, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        markets[id].totalSupplyAssets += uint128(assets);
        markets[id].totalSupplyShares += uint128(assets * SHARE_SCALE);
        return (assets, assets * SHARE_SCALE);
    }

    function repay(MarketParams memory mp, uint256 assets, uint256, address onBehalf, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        uint128 shares = uint128(assets * SHARE_SCALE);
        if (borrowSharesOf[id][onBehalf] < shares) shares = borrowSharesOf[id][onBehalf];
        borrowSharesOf[id][onBehalf] -= shares;
        if (markets[id].totalBorrowAssets >= assets) markets[id].totalBorrowAssets -= uint128(assets);
        else markets[id].totalBorrowAssets = 0;
        if (markets[id].totalBorrowShares >= shares) markets[id].totalBorrowShares -= shares;
        else markets[id].totalBorrowShares = 0;
        return (assets, shares);
    }

    function accrueInterest(MarketParams memory) external pure {}

    function setMarket(bytes32 id, uint128 s, uint128 b) external {
        markets[id].totalSupplyAssets = s;
        markets[id].totalSupplyShares = uint128(uint256(s) * SHARE_SCALE);
        markets[id].totalBorrowAssets = b;
        markets[id].totalBorrowShares = uint128(uint256(b) * SHARE_SCALE);
    }

    function setBorrow(bytes32 id, address user, uint128 b) external {
        borrowSharesOf[id][user] = uint128(uint256(b) * SHARE_SCALE);
        markets[id].totalBorrowAssets = b;
        markets[id].totalBorrowShares = uint128(uint256(b) * SHARE_SCALE);
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        Mkt memory m = markets[id];
        return (m.totalSupplyAssets, m.totalSupplyShares, m.totalBorrowAssets, m.totalBorrowShares, 0, 0);
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128) {
        return (0, borrowSharesOf[id][user], 0);
    }
}

contract MockYrssU {
    MockERC20U public immutable asset;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public liquidity;

    constructor(address asset_) {
        asset = MockERC20U(asset_);
    }

    function mintShares(address to, uint256 assets) external {
        balanceOf[to] += assets;
    }

    function setLiquidity(uint256 amt) external {
        liquidity = amt;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        uint256 claim = balanceOf[owner];
        return claim < liquidity ? claim : liquidity;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        require(msg.sender == owner || allowance[owner][msg.sender] >= assets, "ALLOW");
        require(assets <= maxWithdraw(owner), "MAX");
        balanceOf[owner] -= assets;
        liquidity -= assets;
        if (msg.sender != owner && allowance[owner][msg.sender] != type(uint256).max) {
            allowance[owner][msg.sender] -= assets;
        }
        require(asset.transfer(receiver, assets), "T");
        return assets;
    }
}

contract CrownUnlatchIdleTest is Test {
    address constant KING = address(0x6708);
    address constant LANDING = address(0x5Adc);
    address constant ORACLE = address(0xBEEF);
    address constant IRM = address(0xCAFE);
    address constant RSS = address(0x1212);

    MockERC20U usdc;
    MockMorphoU morpho;
    MockYrssU yrss;
    CrownUnlatchIdle eng;
    bytes32 mid;

    function setUp() public {
        usdc = new MockERC20U();
        morpho = new MockMorphoU();
        yrss = new MockYrssU(address(usdc));
        eng = new CrownUnlatchIdle(address(morpho), address(usdc), address(yrss), KING, LANDING, KING);
        mid = keccak256(abi.encode(address(usdc), RSS, ORACLE, IRM, uint256(77e16)));

        vm.startPrank(KING);
        eng.setMarketRss(RSS, ORACLE, IRM, 77e16, mid);
        morpho.setMarket(mid, 10_000_000e6, 10_000_000e6); // 100% util latched
        usdc.mint(KING, 5_000_000e6);
        usdc.approve(address(eng), type(uint256).max);
        yrss.mintShares(KING, 1_000_000e6);
        yrss.approve(address(eng), type(uint256).max);
        usdc.mint(address(yrss), 1_000_000e6);
        vm.stopPrank();
    }

    function test_engineerIdle_creates_lasting_unlatched_idle() public {
        assertEq(eng.idle(), 0);
        vm.prank(KING);
        uint256 got = eng.engineerIdle(2_000_000e6);
        assertEq(got, 2_000_000e6);
        assertEq(eng.idle(), 2_000_000e6);
        assertEq(eng.minIdleBuffer(), 2_000_000e6); // auto-raised — peel cannot eat it
        assertEq(eng.surplusIdle(), 0);
        (, uint128 b,) = morpho.position(mid, KING);
        assertEq(b, 0); // no king borrow opened
    }

    function test_peel_blocked_while_buffer_holds_idle() public {
        vm.prank(KING);
        eng.engineerIdle(500_000e6);
        yrss.setLiquidity(500_000e6); // vault unlocked by idle, but buffer == idle
        vm.prank(KING);
        vm.expectRevert(CrownUnlatchIdle.WithdrawMiss.selector);
        eng.peelSurplus(0);
    }

    function test_peel_surplus_keeps_buffer() public {
        vm.prank(KING);
        eng.engineerIdle(1_000_000e6);
        // Owner lowers buffer so robots can peel surplus
        vm.prank(KING);
        eng.setMinIdleBuffer(200_000e6);
        yrss.setLiquidity(1_000_000e6);

        vm.prank(KING);
        uint256 peeled = eng.peelSurplus(0);
        assertEq(peeled, 800_000e6);
        // Mock yrss withdraw does not reduce Morpho idle — assert buffer semantics via surplus
        assertEq(eng.minIdleBuffer(), 200_000e6);
        assertEq(usdc.balanceOf(LANDING), 800_000e6);
    }

    function test_unlatchRepay_opens_idle_without_borrow() public {
        morpho.setBorrow(mid, KING, 1_000_000e6);
        morpho.setMarket(mid, 1_000_000e6, 1_000_000e6);
        vm.prank(KING);
        uint256 idleAfter = eng.unlatchRepay(1_000_000e6);
        assertEq(idleAfter, 1_000_000e6);
        assertEq(eng.minIdleBuffer(), 1_000_000e6);
    }

    function test_borrow_gasPark_blocked() public {
        vm.expectRevert(CrownUnlatchIdle.NoBorrow.selector);
        eng.borrow(1);
        vm.expectRevert(CrownUnlatchIdle.NoBorrow.selector);
        eng.gasPark(1, 0);
    }
}
