// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownVaultSolver} from "../src/CrownVaultSolver.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20 {
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

/// @dev Minimal Morpho Blue mock: supply / coll / borrow / repay / market / position.
contract MockMorpho {
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

    struct Pos {
        uint256 supplyShares;
        uint128 borrowShares;
        uint128 collateral;
    }

    mapping(bytes32 => Mkt) public markets;
    mapping(bytes32 => mapping(address => Pos)) public positions;
    mapping(address => mapping(address => bool)) public isAuthorized; // authorizer => authorized

    function setAuthorization(address authorized, bool on) external {
        isAuthorized[msg.sender][authorized] = on;
    }

    function supply(MarketParams memory mp, uint256 assets, uint256, address onBehalf, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        markets[id].totalSupplyAssets += uint128(assets);
        positions[id][onBehalf].supplyShares += assets;
        return (assets, assets);
    }

    function supplyCollateral(MarketParams memory mp, uint256 assets, address onBehalf, bytes memory) external {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.collateralToken).transferFrom(msg.sender, address(this), assets);
        positions[id][onBehalf].collateral += uint128(assets);
    }

    function borrow(MarketParams memory mp, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        require(isAuthorized[onBehalf][msg.sender] || msg.sender == onBehalf, "AUTH");
        Mkt storage m = markets[id];
        uint256 idle = uint256(m.totalSupplyAssets) > uint256(m.totalBorrowAssets)
            ? uint256(m.totalSupplyAssets) - uint256(m.totalBorrowAssets)
            : 0;
        require(assets <= idle, "IDLE");
        m.totalBorrowAssets += uint128(assets);
        positions[id][onBehalf].borrowShares += uint128(assets);
        IERC20(mp.loanToken).transfer(receiver, assets);
        return (assets, assets);
    }

    function repay(MarketParams memory mp, uint256 assets, uint256, address onBehalf, bytes memory)
        external
        returns (uint256, uint256)
    {
        bytes32 id = keccak256(abi.encode(mp));
        IERC20(mp.loanToken).transferFrom(msg.sender, address(this), assets);
        markets[id].totalBorrowAssets -= uint128(assets);
        positions[id][onBehalf].borrowShares -= uint128(assets);
        return (assets, assets);
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        Mkt memory m = markets[id];
        return (m.totalSupplyAssets, 0, m.totalBorrowAssets, 0, 0, 0);
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128) {
        Pos memory p = positions[id][user];
        return (p.supplyShares, p.borrowShares, p.collateral);
    }
}

contract MockCredit {
    IERC20 public immutable usdc;
    uint256 public freeUsdc;

    constructor(address usdc_) {
        usdc = IERC20(usdc_);
    }

    function supply(uint256 amt) external {
        require(usdc.transferFrom(msg.sender, address(this), amt), "T");
        freeUsdc += amt;
    }
}

contract CrownVaultSolverTest is Test {
    address constant KING = address(0x6708);
    address constant LANDING = address(0x5Adc);
    address constant ORACLE = address(0xBEEF);
    address constant IRM = address(0xCAFE);

    MockERC20 usdc;
    MockERC20 eusd;
    MockERC20 gusd;
    MockMorpho morpho;
    MockCredit credit;
    CrownVaultSolver solver;

    bytes32 eusdId;
    bytes32 gusdId;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        eusd = new MockERC20("eUSD", "eUSD", 18);
        gusd = new MockERC20("gUSD", "gUSD", 18);
        morpho = new MockMorpho();
        credit = new MockCredit(address(usdc));

        solver = new CrownVaultSolver(
            address(morpho), address(usdc), address(eusd), address(gusd), KING, LANDING, KING
        );

        IMorphoVaultSolverParams memory ep = IMorphoVaultSolverParams(address(usdc), address(eusd), ORACLE, IRM, 86e16);
        IMorphoVaultSolverParams memory gp = IMorphoVaultSolverParams(address(usdc), address(gusd), ORACLE, IRM, 86e16);
        eusdId = keccak256(abi.encode(ep));
        gusdId = keccak256(abi.encode(gp));

        vm.startPrank(KING);
        solver.setEusdMarket(ORACLE, IRM, 86e16, eusdId);
        solver.setGusdMarket(ORACLE, IRM, 86e16, gusdId);
        morpho.setAuthorization(address(solver), true);
        usdc.mint(KING, 10_000_000e6);
        eusd.mint(KING, 500_000_000e18);
        gusd.mint(KING, 2_000_000_000e18);
        usdc.approve(address(solver), type(uint256).max);
        eusd.approve(address(solver), type(uint256).max);
        gusd.approve(address(solver), type(uint256).max);
        vm.stopPrank();
    }

    function test_willFromZero_peels20_keeps80() public {
        vm.prank(KING);
        (uint256 peeled, uint256 kept) = solver.willFromZero(1_000_000e6, 40_000_000e18, 100_000_000e18, 0);

        // borrow full idle after seed = $1M; peel 20% = 200k; keep 80% = 800k
        assertEq(peeled, 200_000e6);
        assertEq(kept, 800_000e6);
        assertEq(usdc.balanceOf(LANDING), 200_000e6);
        assertEq(solver.lastBorrow(), 1_000_000e6);
        assertEq(solver.totalPeeled(), 200_000e6);
        assertEq(solver.totalKept(), 800_000e6);

        // After: supply = 1M seed + 800k keep = 1.8M; borrow = 1M; idle = 800k
        assertEq(solver.idleEusd(), 800_000e6);
    }

    function test_willLoop_fibonacci_peel() public {
        vm.startPrank(KING);
        solver.willFromZero(1_000_000e6, 40_000_000e18, 0, 0);
        // idle left 800k → loop peels 160k
        (uint256 peeled, uint256 kept) = solver.willLoop(0);
        vm.stopPrank();

        assertEq(peeled, 160_000e6);
        assertEq(kept, 640_000e6);
        assertEq(usdc.balanceOf(LANDING), 360_000e6); // 200k + 160k
    }

    function test_peel_to_credit_when_set() public {
        vm.startPrank(KING);
        solver.setCredit(address(credit));
        (uint256 peeled,) = solver.willFromZero(500_000e6, 10_000_000e18, 0, 0);
        vm.stopPrank();

        assertEq(peeled, 100_000e6);
        assertEq(usdc.balanceOf(LANDING), 0);
        assertEq(credit.freeUsdc(), 100_000e6);
    }

    function test_disarmed_blocks_will() public {
        vm.prank(KING);
        solver.setArmed(false);
        vm.prank(KING);
        vm.expectRevert(CrownVaultSolver.NotArmed.selector);
        solver.willFromZero(1e6, 1e18, 0, 0);
    }

    function test_deposit_then_seedBook() public {
        vm.startPrank(KING);
        solver.deposit(250_000e6);
        assertEq(solver.vaultUsdc(), 250_000e6);
        solver.seedBook(250_000e6);
        assertEq(solver.vaultUsdc(), 0);
        assertEq(solver.idleEusd(), 250_000e6);
        vm.stopPrank();
    }

    function test_ltv_guard_reverts_oversize_borrow() public {
        // 1e18 eUSD @ 70% soft = 0.7e6 USDC max; ask $1 fails
        vm.prank(KING);
        vm.expectRevert(CrownVaultSolver.Ltv.selector);
        solver.willFromZero(1_000_000e6, 1e18, 0, 1_000_000e6);
    }
}

/// @dev Local copy of market params for id hashing in tests.
struct IMorphoVaultSolverParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}
