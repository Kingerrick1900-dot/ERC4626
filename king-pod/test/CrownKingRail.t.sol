// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownKingRail} from "../src/CrownKingRail.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20K {
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

contract MockMorphoK {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    mapping(bytes32 => uint128) public supplyAssets;
    mapping(bytes32 => uint128) public borrowAssets;

    function supply(MarketParams memory mp, uint256 assets, uint256, address, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        supplyAssets[id] += uint128(assets);
        return (assets, assets);
    }

    function withdraw(MarketParams memory mp, uint256 assets, uint256, address, address receiver)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        require(supplyAssets[id] >= assets, "S");
        supplyAssets[id] -= uint128(assets);
        IERC20(mp.loanToken).transfer(receiver, assets);
        return (assets, assets);
    }

    function flashLoan(address, uint256, bytes calldata) external pure {
        revert("no-flash-in-unit");
    }

    function repay(MarketParams memory, uint256, uint256, address, bytes memory) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function supplyCollateral(MarketParams memory, uint256, address, bytes memory) external pure {}

    function borrow(MarketParams memory, uint256, uint256, address, address) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function accrueInterest(MarketParams memory) external pure {}

    function setBook(bytes32 id, uint128 s, uint128 b) external {
        supplyAssets[id] = s;
        borrowAssets[id] = b;
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        return (supplyAssets[id], 0, borrowAssets[id], 0, 0, 0);
    }
}

contract MockYrssK {
    function withdraw(uint256, address, address) external pure returns (uint256) {
        return 0;
    }

    function maxWithdraw(address) external pure returns (uint256) {
        return 0;
    }

    function convertToAssets(uint256) external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }
}

contract CrownKingRailTest is Test {
    address constant KING = address(0x6708);
    address constant LANDING = address(0x5Adc);
    address constant RSS = address(0x1212);
    address constant ORACLE = address(0xBEEF);
    address constant IRM = address(0xCAFE);

    MockERC20K usdc;
    MockERC20K eusd;
    MockERC20K cbbtc;
    MockMorphoK morpho;
    MockYrssK yrss;
    CrownKingRail rail;
    bytes32 eusdId;

    function setUp() public {
        usdc = new MockERC20K();
        eusd = new MockERC20K();
        cbbtc = new MockERC20K();
        morpho = new MockMorphoK();
        yrss = new MockYrssK();
        rail = new CrownKingRail(
            address(morpho), address(usdc), address(eusd), address(cbbtc), address(yrss), KING, LANDING, KING
        );
        eusdId = keccak256(abi.encode(address(eusd), RSS, ORACLE, IRM, uint256(77e16)));
        bytes32 parkId = keccak256(abi.encode(address(usdc), RSS, ORACLE, IRM, uint256(77e16)));
        bytes32 cbId = keccak256(abi.encode(address(usdc), address(cbbtc), ORACLE, IRM, uint256(86e16)));
        vm.prank(KING);
        rail.setMarkets(RSS, ORACLE, ORACLE, ORACLE, IRM, 77e16, 86e16, eusdId, parkId, cbId);
        morpho.setBook(eusdId, 100_000_000e18, 90_000_000e18);
        eusd.mint(KING, 5_000_000e18);
        vm.prank(KING);
        eusd.approve(address(rail), type(uint256).max);
    }

    function test_p2_pipes_eusd_to_landing() public {
        uint256 before = eusd.balanceOf(LANDING);
        vm.prank(KING);
        uint256 got = rail.p2PipeEusdToLanding(2_000_000e18);
        assertEq(got, 2_000_000e18);
        assertEq(eusd.balanceOf(LANDING), before + 2_000_000e18);
        assertEq(rail.totalEusdPiped(), 2_000_000e18);
    }

    function test_gasPark_blocked() public {
        vm.expectRevert(CrownKingRail.NoBorrow.selector);
        rail.gasPark(1, 0);
    }
}
