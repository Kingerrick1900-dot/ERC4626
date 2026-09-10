// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownStayIdlePuller} from "../src/CrownStayIdlePuller.sol";
import {CrownYrssLiberator} from "../src/CrownYrssLiberator.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20S {
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

contract MockMorphoS {
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
    uint256 public constant SHARE_SCALE = 1e6;

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
        if (markets[id].totalBorrowAssets >= assets) {
            markets[id].totalBorrowAssets -= uint128(assets);
        } else {
            markets[id].totalBorrowAssets = 0;
        }
        if (markets[id].totalBorrowShares >= shares) {
            markets[id].totalBorrowShares -= shares;
        } else {
            markets[id].totalBorrowShares = 0;
        }
        return (assets, shares);
    }

    function accrueInterest(MarketParams memory) external pure {}

    function setMarket(bytes32 id, uint128 supplyAssets, uint128 borrowAssets) external {
        markets[id].totalSupplyAssets = supplyAssets;
        markets[id].totalSupplyShares = uint128(uint256(supplyAssets) * SHARE_SCALE);
        markets[id].totalBorrowAssets = borrowAssets;
        markets[id].totalBorrowShares = uint128(uint256(borrowAssets) * SHARE_SCALE);
    }

    function setBorrow(bytes32 id, address user, uint128 borrowAssets) external {
        borrowSharesOf[id][user] = uint128(uint256(borrowAssets) * SHARE_SCALE);
        markets[id].totalBorrowAssets = borrowAssets;
        markets[id].totalBorrowShares = uint128(uint256(borrowAssets) * SHARE_SCALE);
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        Mkt memory m = markets[id];
        return (m.totalSupplyAssets, m.totalSupplyShares, m.totalBorrowAssets, m.totalBorrowShares, 0, 0);
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128) {
        return (0, borrowSharesOf[id][user], 0);
    }
}

/// @dev Vault unlocks withdraw only when liquidity is set (Morpho idle stand-in).
contract MockYrssS {
    MockERC20S public immutable asset;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public liquidity;

    constructor(address asset_) {
        asset = MockERC20S(asset_);
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

contract CrownStayIdlePullerTest is Test {
    address constant KING = address(0x6708);
    address constant LANDING = address(0x5Adc);
    address constant ORACLE = address(0xBEEF);
    address constant IRM = address(0xCAFE);
    address constant RSS = address(0x1212);

    MockERC20S usdc;
    MockMorphoS morpho;
    MockYrssS yrss;
    CrownStayIdlePuller puller;
    CrownYrssLiberator liberator;
    bytes32 mid;

    function setUp() public {
        usdc = new MockERC20S("USDC", "USDC", 6);
        morpho = new MockMorphoS();
        yrss = new MockYrssS(address(usdc));

        puller = new CrownStayIdlePuller(address(morpho), address(usdc), address(yrss), KING, LANDING, KING);
        liberator = new CrownYrssLiberator(address(morpho), address(usdc), address(yrss), KING, LANDING, KING);

        mid = keccak256(abi.encode(address(usdc), RSS, ORACLE, IRM, uint256(77e16)));

        vm.startPrank(KING);
        puller.setMarketRss(RSS, ORACLE, IRM, 77e16, mid);
        liberator.setMarketRss(RSS, ORACLE, IRM, 77e16, mid);

        // Book at 50% util — room under 90% buffer.
        morpho.setMarket(mid, 10_000_000e6, 5_000_000e6);

        usdc.mint(KING, 5_000_000e6);
        usdc.approve(address(puller), type(uint256).max);
        usdc.approve(address(liberator), type(uint256).max);

        yrss.mintShares(KING, 1_000_000e6);
        yrss.approve(address(puller), type(uint256).max);
        yrss.approve(address(liberator), type(uint256).max);
        usdc.mint(address(yrss), 1_000_000e6);
        vm.stopPrank();
    }

    function test_stayIdle_creates_unmatched_idle_no_borrow() public {
        vm.prank(KING);
        uint256 got = puller.stayIdle(2_000_000e6);
        assertEq(got, 2_000_000e6);
        // Prior idle 5M + 2M supply = 7M idle
        assertEq(puller.idle(), 7_000_000e6);
        assertEq(usdc.balanceOf(address(morpho)), 2_000_000e6);
        (, uint128 b,) = morpho.position(mid, KING);
        assertEq(b, 0);
        assertEq(puller.totalSupplied(), 2_000_000e6);
    }

    function test_stayIdle_default_ask_2m() public {
        vm.prank(KING);
        puller.fund(2_000_000e6);
        vm.prank(KING);
        uint256 got = puller.stayIdle(0);
        assertEq(got, 2_000_000e6);
        assertEq(puller.lastSupply(), 2_000_000e6);
    }

    function test_borrow_and_gasPark_hard_blocked() public {
        vm.prank(KING);
        vm.expectRevert(CrownStayIdlePuller.NoBorrow.selector);
        puller.borrow(1);

        vm.prank(KING);
        vm.expectRevert(CrownStayIdlePuller.NoBorrow.selector);
        puller.gasPark(1_000_000e6, 0);
    }

    function test_pullShares_when_liquidity_opens() public {
        assertEq(yrss.maxWithdraw(KING), 0);

        vm.prank(KING);
        puller.stayIdle(2_000_000e6);
        // MetaMorpho stand-in: idle unlocks vault liquidity
        yrss.setLiquidity(1_000_000e6);

        uint256 before = usdc.balanceOf(LANDING);
        vm.prank(KING);
        uint256 peeled = puller.pullSharesToLanding(0);
        assertEq(peeled, 1_000_000e6);
        assertEq(usdc.balanceOf(LANDING) - before, 1_000_000e6);
        assertEq(puller.totalPulled(), 1_000_000e6);
    }

    function test_pokePull_robots_serve() public {
        vm.prank(KING);
        puller.stayIdle(500_000e6);
        yrss.setLiquidity(500_000e6);

        // Anyone can poke once idle + maxWithdraw > 0
        uint256 peeled = puller.pokePull();
        assertEq(peeled, 500_000e6);
        assertEq(usdc.balanceOf(LANDING), 500_000e6);
    }

    function test_liberator_repay_opens_idle_then_shares_to_landing() public {
        // 100% util self-lock: $1M supply = $1M king borrow (gasPark residue)
        morpho.setMarket(mid, 1_000_000e6, 1_000_000e6);
        morpho.setBorrow(mid, KING, 1_000_000e6);
        assertEq(liberator.idle(), 0);
        assertEq(yrss.maxWithdraw(KING), 0);

        usdc.mint(KING, 1_000_000e6);
        yrss.setLiquidity(1_000_000e6); // unlocks as idle opens (stand-in)

        uint256 before = usdc.balanceOf(LANDING);
        vm.prank(KING);
        (uint256 idleAfter, uint256 pulled) = liberator.repayAndLiberate(1_000_000e6, 0);

        assertEq(idleAfter, 1_000_000e6);
        assertEq(pulled, 1_000_000e6);
        assertEq(usdc.balanceOf(LANDING) - before, 1_000_000e6);
        assertEq(liberator.totalRepaid(), 1_000_000e6);
        assertEq(liberator.totalLiberated(), 1_000_000e6);
    }

    function test_liberator_borrow_blocked() public {
        vm.expectRevert(CrownYrssLiberator.NoBorrow.selector);
        liberator.borrow(1);
        vm.expectRevert(CrownYrssLiberator.NoBorrow.selector);
        liberator.gasPark(1, 0);
    }

    function test_liberator_poke_when_idle() public {
        morpho.setMarket(mid, 2_000_000e6, 1_000_000e6); // $1M idle
        yrss.setLiquidity(1_000_000e6);

        uint256 pulled = liberator.pokeLiberate();
        assertEq(pulled, 1_000_000e6);
        assertEq(usdc.balanceOf(LANDING), 1_000_000e6);
    }

    function test_disarmed_blocks_stayIdle() public {
        vm.prank(KING);
        puller.setArmed(false);
        vm.prank(KING);
        vm.expectRevert(CrownStayIdlePuller.NotArmed.selector);
        puller.stayIdle(1e6);
    }
}
