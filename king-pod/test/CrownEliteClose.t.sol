// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {KingSeedDesk} from "../src/KingSeedDesk.sol";
import {CrownEliteClose} from "../src/CrownEliteClose.sol";
import {IMorphoElite} from "../src/CrownEliteClose.sol";

contract MockERC20E {
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

interface IFlashCb {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Minimal Morpho Blue mock: auth, collateral, borrow, repay, flash, HF gate.
contract MockMorphoElite {
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

    mapping(address => bool) public isAuthorized; // user => operator (simplified: operator authorized by user via setAuth)
    mapping(address => mapping(address => bool)) public authorization; // user => operator
    mapping(bytes32 => mapping(address => Pos)) public positions;
    mapping(bytes32 => uint256) public totalSupply;
    mapping(bytes32 => uint256) public totalBorrow;
    uint256 public immutable oraclePrice; // Morpho scale
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

    function supply(MarketParams memory p, uint256 assets, uint256, address onBehalf, bytes calldata) external {
        bytes32 mid = id(p);
        MockERC20E(p.loanToken).transferFrom(msg.sender, address(this), assets);
        positions[mid][onBehalf].supplyAssets += assets;
        totalSupply[mid] += assets;
    }

    function supplyCollateral(MarketParams memory p, uint256 assets, address onBehalf, bytes calldata) external {
        _auth(onBehalf);
        bytes32 mid = id(p);
        MockERC20E(p.collateralToken).transferFrom(msg.sender, address(this), assets);
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
        MockERC20E(p.loanToken).transfer(receiver, assets);
        return (assets, assets);
    }

    function repay(MarketParams memory p, uint256 assets, uint256, address onBehalf, bytes calldata)
        external
        returns (uint256, uint256)
    {
        bytes32 mid = id(p);
        Pos storage pos = positions[mid][onBehalf];
        if (assets > pos.borrowAssets) assets = pos.borrowAssets;
        MockERC20E(p.loanToken).transferFrom(msg.sender, address(this), assets);
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
        MockERC20E(p.collateralToken).transfer(receiver, assets);
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        MockERC20E(token).transfer(msg.sender, assets);
        IFlashCb(msg.sender).onMorphoFlashLoan(assets, data);
        MockERC20E(token).transferFrom(msg.sender, address(this), assets);
    }

    function _requireHealthy(Pos storage pos) internal view {
        if (pos.borrowAssets == 0) return;
        uint256 collValue = (pos.collateral * oraclePrice) / 1e36;
        uint256 maxBorrow = (collValue * lltv) / 1e18;
        require(pos.borrowAssets <= maxBorrow, "HF");
    }
}

contract CrownEliteCloseTest is Test {
    MockERC20E rss;
    MockERC20E usdc;
    MockMorphoElite morpho;
    KingSeedDesk desk;
    CrownEliteClose closer;
    address king = address(0xA11CE);
    address lender = address(0x1E4D);
    address seeder = address(0x5EED);

    uint256 constant PRICE = 5e22; // $0.05 RSS → USDC (Morpho scale)
    uint256 constant LLTV = 0.77e18;
    uint256 constant PRICE_USDC_PER_RSS = 50_000; // desk $0.05

    IMorphoElite.MarketParams params;

    function setUp() public {
        rss = new MockERC20E("RSS", "RSS", 18);
        usdc = new MockERC20E("USDC", "USDC", 6);
        morpho = new MockMorphoElite(PRICE, LLTV);

        desk = new KingSeedDesk(address(rss), address(usdc), king, PRICE_USDC_PER_RSS, king);

        params = IMorphoElite.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(rss),
            oracle: address(0xBEEF),
            irm: address(0xCAFE),
            lltv: LLTV
        });

        closer = new CrownEliteClose(
            address(morpho), address(usdc), address(rss), address(desk), king, king, params, king
        );

        // Liquidity on Morpho market (external lender — Morpho book).
        usdc.mint(lender, 1_000_000e6);
        vm.startPrank(lender);
        usdc.approve(address(morpho), type(uint256).max);
        morpho.supply(MockMorphoElite.MarketParams(params.loanToken, params.collateralToken, params.oracle, params.irm, params.lltv), 700_000e6, 0, lender, "");
        vm.stopPrank();

        // CrownSeedFill inventory (repay-with-collateral rail).
        usdc.mint(seeder, 700_000e6);
        vm.prank(king);
        desk.setSeeder(seeder, true);
        vm.startPrank(seeder);
        usdc.approve(address(desk), type(uint256).max);
        desk.seed(700_000e6);
        vm.stopPrank();

        vm.prank(king);
        desk.setFiller(address(closer), true);

        // King RSS + Morpho auth for closer.
        rss.mint(king, 30_000_000 ether);
        vm.startPrank(king);
        rss.approve(address(closer), type(uint256).max);
        morpho.setAuthorization(address(closer), true);
        vm.stopPrank();

        // Morpho needs USDC inventory for flash (singleton liquidity).
        usdc.mint(address(morpho), 2_000_000e6);
    }

    function testEliteClose_KingKeepsUsdc_MorphoDebtZero() public {
        uint256 B = 100_000e6; // $100k elite sample (scales to 700k same path)
        // Collateral for borrow at 77% LLTV @ $0.05: need collValue*0.77 >= B
        // collValue = rss * 5e22 / 1e36 = rss * 5e4 / 1e18 → rss >= B * 1e18 / 5e4 / 0.77
        uint256 rssForFill = (B * 1e18) / PRICE_USDC_PER_RSS; // exactly $B at desk price
        uint256 rssCollateral = (rssForFill * 100) / 70; // buffer above LLTV for open borrow

        uint256 kingUsdcBefore = usdc.balanceOf(king);

        vm.prank(king);
        closer.eliteClose(rssCollateral, B, rssForFill);

        // Treasury (King in unit test) keeps borrowed USDC free and clear.
        assertEq(usdc.balanceOf(king), kingUsdcBefore + B, "treasury usdc");

        // Morpho debt cleared.
        bytes32 mid = keccak256(abi.encode(params));
        (, uint128 borrowShares, uint128 coll) = morpho.position(mid, king);
        assertEq(uint256(borrowShares), 0, "debt");
        assertEq(uint256(coll), 0, "coll cleared");

        // Fill rail spent B; leftover RSS returned to King path accounted.
        assertEq(desk.inventoryUsdc(), 700_000e6 - B, "fill inventory");
    }

    function testEliteClose_RevertsIfFillShort() public {
        uint256 B = 100_000e6;
        uint256 rssForFill = (B * 1e18) / PRICE_USDC_PER_RSS;
        uint256 rssCollateral = (rssForFill * 100) / 70;

        // rssForFill too small vs B → FillShort preflight
        vm.prank(king);
        vm.expectRevert(CrownEliteClose.FillShort.selector);
        closer.eliteClose(rssCollateral, B, rssForFill / 2);
    }

    function testEliteClose_RevertsIfInventoryEmpty() public {
        uint256 B = 100_000e6;
        uint256 rssForFill = (B * 1e18) / PRICE_USDC_PER_RSS;
        uint256 rssCollateral = (rssForFill * 100) / 70;

        vm.prank(king);
        desk.rescue(address(usdc), 700_000e6, king);

        vm.prank(king);
        vm.expectRevert(KingSeedDesk.Inventory.selector);
        closer.eliteClose(rssCollateral, B, rssForFill);
    }
}
