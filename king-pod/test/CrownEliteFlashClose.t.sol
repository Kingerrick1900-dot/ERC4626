// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {KingSeedDesk} from "../src/KingSeedDesk.sol";
import {CrownEliteFlashClose} from "../src/CrownEliteFlashClose.sol";
import {IMorphoFlashElite} from "../src/CrownEliteFlashClose.sol";

contract MockERC20F {
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

interface IFlashCbF {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Morpho mock with supply/withdraw so flash-rail self-lend works with empty market.
contract MockMorphoFlash {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Pos {
        uint256 supplyAssets;
        uint256 borrowAssets;
        uint256 collateral;
    }

    mapping(address => mapping(address => bool)) public authorization;
    mapping(bytes32 => mapping(address => Pos)) public positions;
    mapping(bytes32 => uint256) public totalSupply;
    mapping(bytes32 => uint256) public totalBorrow;
    uint256 public immutable oraclePrice;
    uint256 public immutable lltv;

    constructor(uint256 oraclePrice_, uint256 lltv_) {
        oraclePrice = oraclePrice_;
        lltv = lltv_;
    }

    function setAuthorization(address operator, bool allowed) external {
        authorization[msg.sender][operator] = allowed;
    }

    function _auth(address onBehalf) internal view {
        require(msg.sender == onBehalf || authorization[onBehalf][msg.sender], "AUTH");
    }

    function id(MarketParams memory p) public pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function position(bytes32 mid, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral)
    {
        Pos storage p = positions[mid][user];
        return (p.supplyAssets, uint128(p.borrowAssets), uint128(p.collateral));
    }

    function supply(MarketParams memory p, uint256 assets, uint256, address onBehalf, bytes calldata)
        external
        returns (uint256, uint256)
    {
        bytes32 mid = id(p);
        MockERC20F(p.loanToken).transferFrom(msg.sender, address(this), assets);
        positions[mid][onBehalf].supplyAssets += assets;
        totalSupply[mid] += assets;
        return (assets, assets);
    }

    function withdraw(MarketParams memory p, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        _auth(onBehalf);
        bytes32 mid = id(p);
        Pos storage pos = positions[mid][onBehalf];
        require(pos.supplyAssets >= assets, "SUP");
        uint256 liquidity = totalSupply[mid] - totalBorrow[mid];
        require(assets <= liquidity, "LIQ");
        pos.supplyAssets -= assets;
        totalSupply[mid] -= assets;
        MockERC20F(p.loanToken).transfer(receiver, assets);
        return (assets, assets);
    }

    function supplyCollateral(MarketParams memory p, uint256 assets, address onBehalf, bytes calldata) external {
        _auth(onBehalf);
        bytes32 mid = id(p);
        MockERC20F(p.collateralToken).transferFrom(msg.sender, address(this), assets);
        positions[mid][onBehalf].collateral += assets;
    }

    function borrow(MarketParams memory p, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        _auth(onBehalf);
        bytes32 mid = id(p);
        Pos storage pos = positions[mid][onBehalf];
        uint256 liquidity = totalSupply[mid] - totalBorrow[mid];
        require(assets <= liquidity, "LIQ");
        pos.borrowAssets += assets;
        totalBorrow[mid] += assets;
        _requireHealthy(pos);
        MockERC20F(p.loanToken).transfer(receiver, assets);
        return (assets, assets);
    }

    function repay(MarketParams memory p, uint256 assets, uint256, address onBehalf, bytes calldata)
        external
        returns (uint256, uint256)
    {
        bytes32 mid = id(p);
        Pos storage pos = positions[mid][onBehalf];
        if (assets > pos.borrowAssets) assets = pos.borrowAssets;
        MockERC20F(p.loanToken).transferFrom(msg.sender, address(this), assets);
        pos.borrowAssets -= assets;
        totalBorrow[mid] -= assets;
        return (assets, assets);
    }

    function withdrawCollateral(MarketParams memory p, uint256 assets, address onBehalf, address receiver) external {
        _auth(onBehalf);
        bytes32 mid = id(p);
        Pos storage pos = positions[mid][onBehalf];
        require(pos.collateral >= assets, "COLL");
        pos.collateral -= assets;
        _requireHealthy(pos);
        MockERC20F(p.collateralToken).transfer(receiver, assets);
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        MockERC20F(token).transfer(msg.sender, assets);
        IFlashCbF(msg.sender).onMorphoFlashLoan(assets, data);
        MockERC20F(token).transferFrom(msg.sender, address(this), assets);
    }

    function _requireHealthy(Pos storage pos) internal view {
        if (pos.borrowAssets == 0) return;
        uint256 collValue = (pos.collateral * oraclePrice) / 1e36;
        uint256 maxBorrow = (collValue * lltv) / 1e18;
        require(pos.borrowAssets <= maxBorrow, "HF");
    }
}

contract CrownEliteFlashCloseTest is Test {
    MockERC20F rss;
    MockERC20F usdc;
    MockMorphoFlash morpho;
    KingSeedDesk desk;
    CrownEliteFlashClose closer;
    address king = address(0xA11CE);
    address seeder = address(0x5EED);
    address vault = address(0xCAEE);

    uint256 constant PRICE = 5e22;
    uint256 constant LLTV = 0.77e18;
    uint256 constant PRICE_USDC_PER_RSS = 50_000;

    IMorphoFlashElite.MarketParams params;

    function setUp() public {
        rss = new MockERC20F("RSS", "RSS", 18);
        usdc = new MockERC20F("USDC", "USDC", 6);
        morpho = new MockMorphoFlash(PRICE, LLTV);

        desk = new KingSeedDesk(address(rss), address(usdc), vault, PRICE_USDC_PER_RSS, king);

        params = IMorphoFlashElite.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(rss),
            oracle: address(0xBEEF),
            irm: address(0xCAFE),
            lltv: LLTV
        });

        closer = new CrownEliteFlashClose(
            address(morpho), address(usdc), address(rss), address(desk), king, vault, params, king
        );

        // Desk only — NO Morpho market pre-fund (the whole point).
        usdc.mint(seeder, 700_000e6);
        vm.prank(king);
        desk.setSeeder(seeder, true);
        vm.startPrank(seeder);
        usdc.approve(address(desk), type(uint256).max);
        desk.seed(700_000e6);
        vm.stopPrank();

        vm.prank(king);
        desk.setFiller(address(closer), true);

        rss.mint(king, 30_000_000 ether);
        vm.startPrank(king);
        rss.approve(address(closer), type(uint256).max);
        morpho.setAuthorization(address(closer), true);
        vm.stopPrank();

        // Global Morpho USDC float for flash (Base Morpho ~$190M).
        usdc.mint(address(morpho), 2_000_000e6);
    }

    function testFlashClose_VaultGetsB_WithDeskOnly_NoMorphoPrefund() public {
        uint256 B = 100_000e6;
        uint256 rssForFill = (B * 1e18) / PRICE_USDC_PER_RSS;
        uint256 rssCollateral = (rssForFill * 100) / 70;

        // Market empty before fire.
        bytes32 mid = keccak256(abi.encode(params));
        assertEq(morpho.totalSupply(mid), 0, "market empty");

        uint256 vaultBefore = usdc.balanceOf(vault);

        vm.prank(king);
        closer.eliteFlashClose(rssCollateral, B, rssForFill);

        assertEq(usdc.balanceOf(vault), vaultBefore + B, "vault +B");
        (, uint128 borrowShares, uint128 coll) = morpho.position(mid, king);
        assertEq(uint256(borrowShares), 0, "debt");
        assertEq(uint256(coll), 0, "coll");
        assertEq(desk.inventoryUsdc(), 700_000e6 - B, "desk spent B");
        // Temporary rail withdrawn — market empty again.
        assertEq(morpho.totalSupply(mid), 0, "rail cleared");
    }

    function testFlashClose_700kPath_DeskOnlyCapital() public {
        uint256 B = 700_000e6;
        uint256 rssForFill = 14_000_000 ether;
        uint256 rssCollateral = 18_200_000 ether;

        uint256 vaultBefore = usdc.balanceOf(vault);
        vm.prank(king);
        closer.eliteFlashClose(rssCollateral, B, rssForFill);
        assertEq(usdc.balanceOf(vault), vaultBefore + B, "700k vault");
    }

    function testFlashClose_RevertsIfFillShort() public {
        uint256 B = 100_000e6;
        uint256 rssForFill = (B * 1e18) / PRICE_USDC_PER_RSS;
        uint256 rssCollateral = (rssForFill * 100) / 70;

        vm.prank(king);
        vm.expectRevert(CrownEliteFlashClose.FillShort.selector);
        closer.eliteFlashClose(rssCollateral, B, rssForFill / 2);
    }
}
