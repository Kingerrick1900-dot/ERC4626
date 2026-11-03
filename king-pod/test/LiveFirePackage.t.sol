// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "../src/lib/Core.sol";
import {CrownColdBuffer} from "../src/CrownColdBuffer.sol";
import {CrownRwaLoop, IRwaSwapper, IMorphoRwa} from "../src/CrownRwaLoop.sol";
import {OceanArb, IOceanRouter} from "../src/OceanArb.sol";

contract MockERC20 is IERC20 {
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

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
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

contract MockYrss {
    MockERC20 public usdc;
    mapping(address => uint256) public maxW;

    constructor(MockERC20 u) {
        usdc = u;
    }

    function asset() external view returns (address) {
        return address(usdc);
    }

    function setMaxWithdraw(address who, uint256 amt) external {
        maxW[who] = amt;
    }

    function maxWithdraw(address who) external view returns (uint256) {
        return maxW[who];
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function convertToAssets(uint256 s) external pure returns (uint256) {
        return s;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        require(maxW[owner] >= assets, "MAX");
        maxW[owner] -= assets;
        usdc.transfer(receiver, assets);
        return assets;
    }
}

contract MockOracle {
    uint256 public priceValue = 1e24; // $1

    function price() external view returns (uint256) {
        return priceValue;
    }
}

contract MockMorpho {
    bool public auth;
    MockERC20 public usdc;
    MockERC20 public rwa;
    mapping(address => uint256) public coll;
    mapping(address => uint256) public debt;

    constructor(MockERC20 u, MockERC20 r) {
        usdc = u;
        rwa = r;
    }

    function setAuth(bool v) external {
        auth = v;
    }

    function isAuthorized(address, address) external view returns (bool) {
        return auth;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        require(token == address(usdc), "T");
        usdc.mint(msg.sender, assets);
        (bool ok,) = msg.sender.call(abi.encodeWithSignature("onMorphoFlashLoan(uint256,bytes)", assets, data));
        require(ok, "CB");
        usdc.transferFrom(msg.sender, address(this), assets);
    }

    function supplyCollateral(IMorphoRwa.MarketParams memory, uint256 assets, address onBehalf, bytes memory)
        external
    {
        rwa.transferFrom(msg.sender, address(this), assets);
        coll[onBehalf] += assets;
    }

    function borrow(IMorphoRwa.MarketParams memory, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        debt[onBehalf] += assets;
        usdc.mint(receiver, assets);
        return (assets, 0);
    }

    function repay(IMorphoRwa.MarketParams memory, uint256 assets, uint256, address onBehalf, bytes memory)
        external
        returns (uint256, uint256)
    {
        usdc.transferFrom(msg.sender, address(this), assets);
        debt[onBehalf] -= assets;
        return (assets, 0);
    }

    function withdrawCollateral(IMorphoRwa.MarketParams memory, uint256, address, address) external {}

    function position(bytes32, address user) external view returns (uint256, uint128, uint128) {
        return (0, uint128(debt[user]), uint128(coll[user]));
    }

    function idToMarketParams(bytes32)
        external
        pure
        returns (address, address, address, address, uint256)
    {
        return (address(0), address(0), address(0), address(0), 0);
    }

    function createMarket(IMorphoRwa.MarketParams memory) external {}
}

contract MockSwapper is IRwaSwapper {
    MockERC20 public usdc;
    MockERC20 public rwa;

    constructor(MockERC20 u, MockERC20 r) {
        usdc = u;
        rwa = r;
    }

    function usdcToRwa(uint256 usdcIn, uint256) external returns (uint256 rwaOut) {
        usdc.transferFrom(msg.sender, address(this), usdcIn);
        rwaOut = usdcIn * 1e12; // 1:1 scaled
        rwa.mint(msg.sender, rwaOut);
    }

    function rwaToUsdc(uint256 rwaIn, uint256) external returns (uint256 usdcOut) {
        rwa.transferFrom(msg.sender, address(this), rwaIn);
        usdcOut = rwaIn / 1e12;
        usdc.mint(msg.sender, usdcOut);
    }
}

contract MockOceanRouter is IOceanRouter {
    MockERC20 public usdc;
    uint256 public edgeBps = 20;

    constructor(MockERC20 u) {
        usdc = u;
    }

    function rotate(uint256 usdcIn, uint256 minUsdcOut, bytes calldata) external returns (uint256 usdcOut) {
        usdc.transferFrom(msg.sender, address(this), usdcIn);
        usdcOut = usdcIn + (usdcIn * edgeBps) / 10_000;
        require(usdcOut >= minUsdcOut, "EDGE");
        usdc.mint(msg.sender, usdcOut); // profit minted = edge (sim)
    }
}

contract LiveFirePackageTest is Test {
    address king = address(0x6708);
    address landing = address(0x5Adc);

    MockERC20 usdc;
    MockERC20 rwa;
    MockYrss yrss;
    MockMorpho morpho;
    MockOracle oracle;
    MockSwapper swapper;
    CrownColdBuffer cold;
    CrownRwaLoop loop_;
    OceanArb ocean;
    MockOceanRouter oceanRouter;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        rwa = new MockERC20("USDY", "USDY", 18);
        yrss = new MockYrss(usdc);
        morpho = new MockMorpho(usdc, rwa);
        oracle = new MockOracle();
        swapper = new MockSwapper(usdc, rwa);
        cold = new CrownColdBuffer(address(usdc), king, landing, address(this));
        loop_ = new CrownRwaLoop(
            address(usdc), address(rwa), address(yrss), address(morpho), king, address(this), 10_000_000e6
        );
        ocean = new OceanArb(address(usdc), king, address(this), 3_000_000e6);
        oceanRouter = new MockOceanRouter(usdc);

        IMorphoRwa.MarketParams memory mp = IMorphoRwa.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(rwa),
            oracle: address(oracle),
            irm: address(0x1234),
            lltv: 0.85e18
        });
        loop_.setMarket(mp, keccak256(abi.encode(mp)));
        loop_.setSwapper(address(swapper));
        loop_.setColdBuffer(address(cold));
        loop_.setTargetLtvBps(8500);
        morpho.setAuth(true);
        loop_.setArmed(true);

        cold.setPusher(address(loop_), true);
        cold.setPusher(address(ocean), true);

        ocean.setRouter(address(oceanRouter));
        ocean.setColdBuffer(address(cold));
        ocean.setArmed(true);
    }

    function test_pilotCapRejectsFake90M() public {
        vm.expectRevert();
        loop_.setPilotCap(90_000_000e6);
    }

    function test_seedAndLoopPushesCapacity() public {
        usdc.mint(address(this), 1_000_000e6);
        usdc.approve(address(loop_), 1_000_000e6);
        loop_.seedUsdc(1_000_000e6);
        loop_.loopIdle(9800);
        assertEq(loop_.totalPulled(), 1_000_000e6);
        assertGt(loop_.totalRwaHeld(), 0);
        assertGt(loop_.totalBorrowed(), 0);
    }

    function test_flashLeverageAtomic() public {
        // 85% LTV: equity 150k + flash 850k → buy 1M RWA → borrow 850k to repay flash
        usdc.mint(address(this), 150_000e6);
        usdc.approve(address(loop_), 150_000e6);
        loop_.seedUsdc(150_000e6);
        loop_.flashLeverage(850_000e6, 9800);
        assertEq(loop_.totalPulled(), 150_000e6);
        assertGt(loop_.totalRwaHeld(), 0);
        assertEq(loop_.totalBorrowed(), 850_000e6);
    }

    function test_oceanRotateAndPushProfit() public {
        usdc.mint(address(this), 3_000_000e6);
        usdc.approve(address(ocean), 3_000_000e6);
        ocean.seed(3_000_000e6);
        uint256 profit = ocean.rotate(1_000_000e6, hex"");
        assertEq(profit, 2_000e6); // 0.2% of 1M
        ocean.pushProfit(0);
        assertEq(cold.balance(), 2_000e6);
    }

    function test_pullFromYrssRequiresLiquidity() public {
        yrss.setMaxWithdraw(king, 0);
        usdc.mint(address(yrss), 100e6);
        vm.expectRevert();
        loop_.pullFromYrss(100e6);
    }

    function test_pullFromYrssWhenLiquid() public {
        usdc.mint(address(yrss), 2_000_000e6);
        yrss.setMaxWithdraw(king, 2_000_000e6);
        loop_.pullFromYrss(2_000_000e6);
        assertEq(loop_.totalPulled(), 2_000_000e6);
        loop_.loopIdle(9800);
        assertGt(loop_.totalRwaHeld(), 0);
    }
}
