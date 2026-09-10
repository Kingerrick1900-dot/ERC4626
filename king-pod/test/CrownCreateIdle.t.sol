// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownCreateIdle} from "../src/CrownCreateIdle.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20I {
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

contract MockMorphoI {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Mkt {
        uint128 totalSupplyAssets;
        uint128 totalBorrowAssets;
    }

    mapping(bytes32 => Mkt) public markets;

    function supply(MarketParams memory mp, uint256 assets, uint256, address, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        markets[id].totalSupplyAssets += uint128(assets);
        return (assets, assets);
    }

    function setBorrow(bytes32 id, uint128 b) external {
        markets[id].totalBorrowAssets = b;
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        Mkt memory m = markets[id];
        return (m.totalSupplyAssets, 0, m.totalBorrowAssets, 0, 0, 0);
    }
}

/// @dev Minimal ERC4626-like vault that unlocks withdraw only when Morpho idle exists.
contract MockYrssI {
    MockERC20I public immutable usdc;
    MockMorphoI public immutable morpho;
    bytes32 public marketId;
    mapping(address => uint256) public balanceOf; // asset claim (USDC units) for simplicity
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address usdc_, address morpho_) {
        usdc = MockERC20I(usdc_);
        morpho = MockMorphoI(morpho_);
    }

    function setMarketId(bytes32 id) external {
        marketId = id;
    }

    function mintShares(address to, uint256 assets) external {
        balanceOf[to] += assets;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    function _idle() internal view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        uint256 claim = balanceOf[owner];
        uint256 idle = _idle();
        // Vault holds no loose USDC; withdraw limited by Morpho idle (liquidity)
        return claim < idle ? claim : idle;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        require(msg.sender == owner || allowance[owner][msg.sender] >= assets, "ALLOW");
        uint256 maxW = maxWithdraw(owner);
        require(assets <= maxW, "MAX");
        balanceOf[owner] -= assets;
        if (msg.sender != owner && allowance[owner][msg.sender] != type(uint256).max) {
            allowance[owner][msg.sender] -= assets;
        }
        // Pull liquidity from Morpho mock: reduce supply (simulate withdraw)
        // In mock, Morpho holds USDC — transfer out to receiver
        require(usdc.balanceOf(address(morpho)) >= assets, "MORPHO");
        // morpho can't transfer itself easily — king test mints to morpho; use raw balance move
        usdc.transferFrom(address(morpho), receiver, assets); // won't work without approve
        // Instead: morpho is EOAsim — test will pre-approve. Fallback: mint to receiver from thin air matching idle physics
        // Simpler path for unit test: usdc already on this vault for the unlocked slice
        return assets;
    }
}

/// @dev Fixed mock: yrss holds a USDC buffer equal to idle unlocks for clean unit tests.
contract MockYrssSimple {
    MockERC20I public immutable asset;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public liquidity; // unlocked by createIdle externally in test

    constructor(address asset_) {
        asset = MockERC20I(asset_);
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

contract CrownCreateIdleTest is Test {
    address constant KING = address(0x6708);
    address constant LANDING = address(0x5Adc);
    address constant ORACLE = address(0xBEEF);
    address constant IRM = address(0xCAFE);
    address constant RSS = address(0x1212);

    MockERC20I usdc;
    MockMorphoI morpho;
    MockYrssSimple yrss;
    CrownCreateIdle idleFill;
    bytes32 mid;

    function setUp() public {
        usdc = new MockERC20I("USDC", "USDC", 6);
        morpho = new MockMorphoI();
        yrss = new MockYrssSimple(address(usdc));

        idleFill = new CrownCreateIdle(address(morpho), address(usdc), address(yrss), KING, LANDING, KING);

        mid = keccak256(
            abi.encode(
                address(usdc), // loanToken
                RSS, // collateralToken
                ORACLE,
                IRM,
                uint256(77e16)
            )
        );

        vm.startPrank(KING);
        idleFill.setMarketRss(RSS, ORACLE, IRM, 77e16, mid);
        usdc.mint(KING, 5_000_000e6);
        usdc.approve(address(idleFill), type(uint256).max);
        yrss.mintShares(KING, 2_000_000e6); // $2M paper claim
        yrss.approve(address(idleFill), type(uint256).max);
        // yrss holds USDC to pay Landing when liquidity unlocks
        usdc.mint(address(yrss), 2_000_000e6);
        vm.stopPrank();
    }

    function test_createIdle_2m_direct_morpho_not_yrss() public {
        vm.prank(KING);
        uint256 supplied = idleFill.createIdle(2_000_000e6);

        assertEq(supplied, 2_000_000e6);
        assertEq(idleFill.idle(), 2_000_000e6);
        assertEq(idleFill.totalCreated(), 2_000_000e6);
        // USDC left the king/helper into Morpho — not into yRSS
        assertEq(usdc.balanceOf(address(morpho)), 2_000_000e6);
        assertEq(usdc.balanceOf(address(yrss)), 2_000_000e6); // unchanged buffer
    }

    function test_createIdle_zero_defaults_to_ask_2m() public {
        vm.prank(KING);
        idleFill.fund(2_000_000e6);
        vm.prank(KING);
        uint256 supplied = idleFill.createIdle(0);
        assertEq(supplied, 2_000_000e6);
        assertEq(idleFill.lastCreate(), 2_000_000e6);
    }

    function test_before_idle_maxWithdraw_dust_then_pull100() public {
        // Before createIdle: no liquidity → maxWithdraw 0
        assertEq(yrss.maxWithdraw(KING), 0);

        vm.prank(KING);
        idleFill.createIdle(2_000_000e6);

        // Unlock vault liquidity to match Morpho idle (MetaMorpho physics stand-in)
        yrss.setLiquidity(2_000_000e6);
        assertEq(yrss.maxWithdraw(KING), 2_000_000e6);

        uint256 landBefore = usdc.balanceOf(LANDING);
        vm.prank(KING);
        uint256 pulled = idleFill.pull100ToLanding(0);
        assertEq(pulled, 2_000_000e6);
        assertEq(usdc.balanceOf(LANDING), landBefore + 2_000_000e6);
        assertEq(idleFill.totalPulled(), 2_000_000e6);
    }

    function test_createIdleAndPull100_one_shot() public {
        yrss.setLiquidity(0);
        vm.prank(KING);
        // one-shot will supply then try pull — need liquidity set mid-flight; simulate by pre-setting
        // liquidity to 2M so after supply, pull works (mock does not auto-link morpho idle)
        yrss.setLiquidity(2_000_000e6);
        vm.prank(KING);
        (uint256 s, uint256 p) = idleFill.createIdleAndPull100(2_000_000e6, 0);
        assertEq(s, 2_000_000e6);
        assertEq(p, 2_000_000e6);
        assertEq(usdc.balanceOf(LANDING), 2_000_000e6);
    }

    function test_disarmed_blocks() public {
        vm.prank(KING);
        idleFill.setArmed(false);
        vm.prank(KING);
        vm.expectRevert(CrownCreateIdle.NotArmed.selector);
        idleFill.createIdle(1e6);
    }
}
