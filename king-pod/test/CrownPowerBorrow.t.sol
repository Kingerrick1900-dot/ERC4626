// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownPowerBorrow, IMorphoPower} from "../src/CrownPowerBorrow.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20PB is IERC20 {
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

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockMorphoPB {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    MockERC20PB public usdc;
    mapping(address => uint256) public supplyOf;
    mapping(address => uint256) public collOf;
    mapping(address => uint256) public debtOf;

    constructor(address usdc_) {
        usdc = MockERC20PB(usdc_);
    }

    function supply(MarketParams memory, uint256 assets, uint256, address onBehalf, bytes calldata)
        external
        returns (uint256, uint256)
    {
        usdc.transferFrom(msg.sender, address(this), assets);
        supplyOf[onBehalf] += assets;
        return (assets, assets);
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata) external {
        // RSS pulled by desk already; desk holds it — accept transferFrom desk
        collOf[onBehalf] += assets;
        IERC20(0x7a305D07B537359cf468eAea9bb176E5308bC337); // silence
        // pull whatever collateral token desk approved — use generic from desk balance via transferFrom on rss in test
    }

    function borrow(MarketParams memory, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        require(supplyOf[onBehalf] >= assets, "LIQ");
        debtOf[onBehalf] += assets;
        usdc.transfer(receiver, assets);
        return (assets, assets);
    }
}

/// @dev Minimal morpho that also pulls RSS on supplyCollateral
contract MockMorphoPB2 {
    MockERC20PB public usdc;
    MockERC20PB public rss;
    mapping(address => uint256) public supplyOf;
    mapping(address => uint256) public collOf;
    mapping(address => uint256) public debtOf;

    constructor(address usdc_, address rss_) {
        usdc = MockERC20PB(usdc_);
        rss = MockERC20PB(rss_);
    }

    function supply(IMorphoPower.MarketParams memory, uint256 assets, uint256, address onBehalf, bytes calldata)
        external
        returns (uint256, uint256)
    {
        usdc.transferFrom(msg.sender, address(this), assets);
        supplyOf[onBehalf] += assets;
        return (assets, assets);
    }

    function supplyCollateral(IMorphoPower.MarketParams memory, uint256 assets, address onBehalf, bytes calldata)
        external
    {
        rss.transferFrom(msg.sender, address(this), assets);
        collOf[onBehalf] += assets;
    }

    function borrow(IMorphoPower.MarketParams memory, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        require(supplyOf[onBehalf] >= debtOf[onBehalf] + assets, "LIQ");
        debtOf[onBehalf] += assets;
        usdc.transfer(receiver, assets);
        return (assets, assets);
    }
}

contract CrownPowerBorrowTest is Test {
    MockERC20PB usdc;
    MockERC20PB rss;
    MockMorphoPB2 morpho;
    CrownPowerBorrow pb;
    address king = address(0xA11CE);
    address vault = address(0xBEEF);
    address owner = address(this);

    function setUp() public {
        usdc = new MockERC20PB("USDC", "USDC", 6);
        rss = new MockERC20PB("RSS", "RSS", 18);
        morpho = new MockMorphoPB2(address(usdc), address(rss));

        IMorphoPower.MarketParams memory params = IMorphoPower.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(rss),
            oracle: address(1),
            irm: address(2),
            lltv: 0.77e18
        });

        pb = new CrownPowerBorrow(address(morpho), address(usdc), address(rss), king, vault, params, owner);

        usdc.mint(king, 100_000e6);
        rss.mint(king, 5_000_000e18);

        vm.prank(king);
        usdc.approve(address(pb), type(uint256).max);
        vm.prank(king);
        rss.approve(address(pb), type(uint256).max);
    }

    function test_powerBorrow_landsVault_holdsDebt() public {
        pb.powerBorrow(100_000e6, 5_000_000e18, 100_000e6);

        assertEq(usdc.balanceOf(vault), 100_000e6);
        assertEq(morpho.debtOf(king), 100_000e6);
        assertEq(morpho.collOf(king), 5_000_000e18);
        assertEq(morpho.supplyOf(king), 100_000e6);
    }

    function test_revert_borrowBiggerThanSeed() public {
        vm.expectRevert(CrownPowerBorrow.Zero.selector);
        pb.powerBorrow(50_000e6, 5_000_000e18, 100_000e6);
    }
}
