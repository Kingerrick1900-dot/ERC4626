// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownFakeIdleEusd} from "../src/CrownFakeIdleEusd.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockEusd {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isMinter;
    address public owner;

    constructor() {
        owner = msg.sender;
        isMinter[msg.sender] = true;
    }

    function setMinter(address a, bool v) external {
        require(msg.sender == owner, "OWN");
        isMinter[a] = v;
    }

    function mint(address to, uint256 amt) external {
        require(isMinter[msg.sender], "MINT");
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

contract MockMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    mapping(bytes32 => uint128) public supplyAssets;
    mapping(bytes32 => uint128) public borrowAssets;
    mapping(bytes32 => mapping(address => uint128)) public borrowSharesOf;

    function supply(MarketParams memory mp, uint256 assets, uint256, address, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        supplyAssets[id] += uint128(assets);
        return (assets, assets);
    }

    function setBook(bytes32 id, uint128 s, uint128 b) external {
        supplyAssets[id] = s;
        borrowAssets[id] = b;
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        return (supplyAssets[id], 0, borrowAssets[id], 0, 0, 0);
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128) {
        return (0, borrowSharesOf[id][user], 0);
    }
}

contract CrownFakeIdleEusdTest is Test {
    address constant KING = address(0x6708);
    address constant COLL = address(0x1212);
    address constant ORACLE = address(0xBEEF);
    address constant IRM = address(0xCAFE);

    MockEusd eusd;
    MockMorphoE morpho;
    CrownFakeIdleEusd fake;
    bytes32 mid;

    function setUp() public {
        eusd = new MockEusd();
        morpho = new MockMorphoE();
        fake = new CrownFakeIdleEusd(address(morpho), address(eusd), KING, KING);
        mid = keccak256(abi.encode(address(eusd), COLL, ORACLE, IRM, uint256(77e16)));
        vm.prank(KING);
        fake.setMarket(COLL, ORACLE, IRM, 77e16, mid);
        morpho.setBook(mid, 100_000_000e18, 96_000_000e18); // ~4% idle already
        eusd.mint(KING, 10_000_000e18);
        vm.prank(KING);
        eusd.approve(address(fake), type(uint256).max);
    }

    function test_engineer_fake_idle_2m_no_borrow() public {
        uint256 before = fake.idle();
        vm.prank(KING);
        uint256 got = fake.engineerFakeIdle(2_000_000e18, false);
        assertEq(got, 2_000_000e18);
        assertEq(fake.idle(), before + 2_000_000e18);
        (, uint128 b,) = morpho.position(mid, KING);
        assertEq(b, 0);
    }

    function test_mint_path_engineers_idle() public {
        eusd.setMinter(address(fake), true);
        vm.prank(KING);
        fake.setMintEnabled(true);
        uint256 before = fake.idle();
        vm.prank(KING);
        fake.engineerFakeIdle(2_000_000e18, true);
        assertEq(fake.idle(), before + 2_000_000e18);
    }

    function test_borrow_blocked() public {
        vm.expectRevert(CrownFakeIdleEusd.NoBorrow.selector);
        fake.borrow(1);
    }
}
