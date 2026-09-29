// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownPoolEngineer} from "../src/CrownPoolEngineer.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        require(al >= a && balanceOf[f] >= a, "X");
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract MockYrss is MockERC20 {
    MockERC20 public usdcTok;

    constructor(MockERC20 u) {
        usdcTok = u;
    }

    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function redeem(uint256 shares, address receiver, address) external returns (uint256 assets) {
        balanceOf[msg.sender] -= shares;
        assets = shares;
        usdcTok.mint(receiver, assets);
    }
}

contract MockEusd {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isMinter;

    function setMinter(address a, bool ok) external {
        isMinter[a] = ok;
    }

    function mint(address to, uint256 a) external {
        require(isMinter[msg.sender], "M");
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        require(al >= a && balanceOf[f] >= a, "X");
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract MockNpm {
    MockERC20 public usdc;
    MockEusd public eusdTok;
    uint256 public poolUsdc;
    uint256 public nextId = 1;

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    constructor(MockERC20 u, MockEusd e) {
        usdc = u;
        eusdTok = e;
    }

    function mint(MintParams calldata p)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        amount0 = p.amount0Desired;
        amount1 = p.amount1Desired;
        require(usdc.transferFrom(msg.sender, address(this), amount0), "0");
        require(eusdTok.transferFrom(msg.sender, address(this), amount1), "1");
        poolUsdc += amount0;
        tokenId = nextId++;
        liquidity = uint128(amount0);
    }
}

contract PoolEngineerTest is Test {
    MockERC20 usdc;
    MockERC20 rss;
    MockEusd eusd;
    MockYrss yrss;
    MockNpm npm;
    CrownPoolEngineer eng;
    address hot;
    address king;

    function setUp() public {
        hot = makeAddr("hot");
        king = makeAddr("king");
        usdc = new MockERC20();
        rss = new MockERC20();
        eusd = new MockEusd();
        yrss = new MockYrss(usdc);
        npm = new MockNpm(usdc, eusd);
        eng = new CrownPoolEngineer(
            address(yrss), address(eusd), address(usdc), address(rss), address(npm), hot, address(0), king
        );
        eusd.setMinter(address(eng), true);
        rss.mint(hot, 1_000_000e18);
        yrss.mint(hot, 50_000e6);
        vm.prank(hot);
        yrss.approve(address(eng), type(uint256).max);
    }

    function test_seed_from_usdc_raises_pool_no_rss_sell() public {
        uint256 rssBefore = rss.balanceOf(hot);
        uint256 poolBefore = npm.poolUsdc();
        usdc.mint(hot, 10_000e6);
        vm.startPrank(hot);
        usdc.approve(address(eng), 10_000e6);
        (uint256 tokenId, uint128 liq) = eng.seedFromUsdc(10_000e6, false);
        vm.stopPrank();
        assertGt(tokenId, 0);
        assertGt(uint256(liq), 0);
        assertEq(npm.poolUsdc(), poolBefore + 10_000e6);
        assertEq(rss.balanceOf(hot), rssBefore);
    }
}

contract PoolEngineerForkTest is Test {
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant POOL = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("BASE_RPC", string(""));
        vm.skip(bytes(rpc).length == 0);
        vm.createSelectFork(rpc);
    }

    function test_fork_engineer_seed_pool_usdc_up() public {
        // yRSS maxWithdraw=0 (fully allocated). Deal USDC stands for Morpho-borrow / dealloc margin.
        CrownPoolEngineer eng = new CrownPoolEngineer(YRSS, EUSD, USDC, RSS, NPM, HOT, ATTEST, HOT);
        vm.prank(HOT);
        IMinter(EUSD).setMinter(address(eng), true);

        uint256 usdcAmt = 500e6;
        deal(USDC, HOT, usdcAmt);
        uint256 poolBefore = IERC20b(USDC).balanceOf(POOL);
        uint256 rssBefore = IERC20b(RSS).balanceOf(HOT);

        vm.startPrank(HOT);
        IERC20b(USDC).approve(address(eng), usdcAmt);
        (uint256 tokenId,) = eng.seedFromUsdc(usdcAmt, true);
        vm.stopPrank();

        assertGt(tokenId, 0);
        assertGt(IERC20b(USDC).balanceOf(POOL), poolBefore);
        assertGe(IERC20b(RSS).balanceOf(HOT), rssBefore);
    }
}

interface IMinter {
    function setMinter(address, bool) external;
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}
