// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownPSMFiller} from "../src/CrownPSMFiller.sol";

contract MockERC20 {
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

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
        totalSupply += a;
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

contract MockLsr {
    MockERC20 public usdc;
    MockERC20 public eusd;
    constructor(MockERC20 u, MockERC20 e) {
        usdc = u;
        eusd = e;
    }

    function usdcReserves() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function sellGem(uint256 usdcAmt) external returns (uint256 eusdOut) {
        require(usdc.transferFrom(msg.sender, address(this), usdcAmt), "pull");
        eusdOut = usdcAmt * 1e12;
        eusd.mint(msg.sender, eusdOut);
    }
}

contract MockMorpho {
    address public cb;
    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        MockERC20(token).transfer(msg.sender, assets);
        CrownPSMFiller(payable(msg.sender)).onMorphoFlashLoan(assets, data);
        require(MockERC20(token).transferFrom(msg.sender, address(this), assets), "repay");
    }
}

contract MockRouter {
    MockERC20 public eusd;
    MockERC20 public usdc;
    uint256 public outPerIn; // USDC out per 1e18 eUSD, scaled 1e6

    constructor(MockERC20 e, MockERC20 u) {
        eusd = e;
        usdc = u;
        outPerIn = 1e6; // 1:1
    }

    function setOut(uint256 v) external {
        outPerIn = v;
    }

    function exactInputSingle(ISwapRouter02.ExactInputSingleParams calldata p)
        external
        payable
        returns (uint256 amountOut)
    {
        require(eusd.transferFrom(msg.sender, address(this), p.amountIn), "in");
        amountOut = (p.amountIn * outPerIn) / 1e18;
        if (amountOut < p.amountOutMinimum) revert("min");
        usdc.mint(p.recipient, amountOut);
    }
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
}

contract PsmFillerTest is Test {
    MockERC20 usdc;
    MockERC20 usdt;
    MockERC20 eusd;
    MockLsr lsr;
    MockMorpho morpho;
    MockRouter router;
    CrownPSMFiller filler;
    address hot;
    address king;
    address agent;

    function setUp() public {
        hot = makeAddr("hot");
        king = makeAddr("king");
        agent = makeAddr("agent");
        usdc = new MockERC20("USDC", "USDC", 6);
        usdt = new MockERC20("USDT", "USDT", 6);
        eusd = new MockERC20("eUSD", "eUSD", 18);
        lsr = new MockLsr(usdc, eusd);
        morpho = new MockMorpho();
        router = new MockRouter(eusd, usdc);
        usdc.mint(address(morpho), 10_000_000e6);

        filler = new CrownPSMFiller(
            address(lsr), address(morpho), address(router), address(usdc), address(usdt), address(eusd), hot, king
        );
        vm.prank(king);
        filler.setAgent(agent);
    }

    function test_fill_raises_lsr_usdc() public {
        usdc.mint(agent, 2_000e6);
        vm.startPrank(agent);
        usdc.approve(address(filler), 2_000e6);
        uint256 before = lsr.usdcReserves();
        uint256 eOut = filler.fill(address(usdc), 2_000e6);
        vm.stopPrank();
        assertEq(lsr.usdcReserves(), before + 2_000e6);
        assertEq(eOut, 2_000e6 * 1e12);
        assertEq(eusd.balanceOf(hot), eOut);
    }

    function test_flash_fill_raises_lsr_when_exit_covers() public {
        // Router mints USDC 1:1 so repay works; LSR keeps flashed USDC
        router.setOut(1e6);
        uint256 before = lsr.usdcReserves();
        vm.prank(agent);
        filler.flashFill(address(usdc), 5_000e6, 0);
        assertEq(lsr.usdcReserves(), before + 5_000e6);
    }
}

/// @dev Base fork — prove live LSR USDC rises after sellGem via filler.
contract PsmFillerForkTest is Test {
    address constant LSR = 0x3edeD70F8ACa4472948E7D3AE3Ad95D63ECdda4F;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("BASE_RPC", string(""));
        vm.skip(bytes(rpc).length == 0);
        vm.createSelectFork(rpc);
    }

    function test_fork_fill_lsr_usdc_up() public {
        CrownPSMFiller filler =
            new CrownPSMFiller(LSR, MORPHO, ROUTER, USDC, USDT, EUSD, HOT, HOT);
        uint256 amt = 1_000e6; // $1k
        deal(USDC, HOT, amt);
        uint256 before = IERC20Bal(USDC).balanceOf(LSR);
        vm.startPrank(HOT);
        IERC20Bal(USDC).approve(address(filler), amt);
        filler.fill(USDC, amt);
        vm.stopPrank();
        uint256 after_ = IERC20Bal(USDC).balanceOf(LSR);
        assertGt(after_, before);
        assertEq(after_ - before, amt);
    }
}

interface IERC20Bal {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}
