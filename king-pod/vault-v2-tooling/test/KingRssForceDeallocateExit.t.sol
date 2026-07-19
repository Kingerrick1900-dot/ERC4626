// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {VaultV2} from "vault-v2/VaultV2.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {IMorphoMarketV1AdapterV2} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2.sol";
import {IMorphoMarketV1AdapterV2Factory} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2Factory.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams, Id, Market} from "morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from "morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

/// @notice Fork-prove Vault V2 forceDeallocate exit on King RSS/USDC Morpho Blue market at 100% util.
/// @dev Access proof only — not an outside-TVL claim. Landing wallet is final owner.
contract KingRssForceDeallocateExit is Test {
    using MorphoBalancesLib for IMorpho;

    address constant VAULT_V2_FACTORY = 0x4501125508079A99ebBebCE205DeC9593C2b5857;
    address constant ADAPTER_FACTORY = 0x9a1B378C43BA535cDB89934230F0D3890c51C0EB;
    address constant ADAPTER_REGISTRY = 0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ADAPTIVE_CURVE_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    /// @dev New Kingdom landing wallet (final V2 owner / exit destination).
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    uint256 constant PENALTY = 0.01e18; // 1%
    uint256 constant WAD = 1e18;
    uint256 constant SEED = 100_000e6; // $100k USDC seed for exit proof
    uint256 constant DEAD = 1e12; // Morpho dead-deposit size for 6dp asset

    address deployer = makeAddr("kingDeployer");
    address borrower = makeAddr("selfBorrower");

    VaultV2 vault;
    address adapter;
    MarketParams marketParams;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://base-mainnet.public.blastapi.io")));

        marketParams = IMorpho(MORPHO).idToMarketParams(Id.wrap(MARKET_ID));
        require(marketParams.loanToken == USDC, "loan");
        require(marketParams.collateralToken == RSS, "coll");
        require(marketParams.irm == ADAPTIVE_CURVE_IRM, "irm");

        deal(USDC, deployer, SEED + DEAD * 2 + 1_000e6);
        deal(RSS, borrower, 50_000_000e18); // ample RSS for 77% LLTV borrow

        _deployKingVaultV2();
        _setForceDeallocatePenalty();
    }

    function _deployKingVaultV2() internal {
        vm.startPrank(deployer);

        bytes32 salt = keccak256(abi.encodePacked("king-yrss-v2", block.timestamp, gasleft()));
        vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(deployer, USDC, salt));
        vault.setCurator(deployer);

        adapter = IMorphoMarketV1AdapterV2Factory(ADAPTER_FACTORY).createMorphoMarketV1AdapterV2(address(vault));

        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (deployer, true)));
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (ADAPTER_REGISTRY)));
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setAdapterRegistry.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setSendSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveAssetsGate.selector)));

        vault.setAdapterRegistry(ADAPTER_REGISTRY);
        vault.setIsAllocator(deployer, true);
        vault.addAdapter(adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);
        vault.abdicate(IVaultV2.setAdapterRegistry.selector);
        vault.abdicate(IVaultV2.setReceiveSharesGate.selector);
        vault.abdicate(IVaultV2.setSendSharesGate.selector);
        vault.abdicate(IVaultV2.setReceiveAssetsGate.selector);

        // Allocator-only (not timelocked)
        bytes memory liquidityData = abi.encode(marketParams);
        vault.setLiquidityAdapterAndData(adapter, liquidityData);

        // Market dead deposit (inflation / listing hygiene; private vault still benefits)
        IERC20(USDC).approve(MORPHO, DEAD);
        IMorpho(MORPHO).supply(marketParams, DEAD, 0, address(0xdead), hex"");

        bytes memory collId = abi.encode("collateralToken", marketParams.collateralToken);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (collId, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (collId, 1e18)));
        vault.increaseAbsoluteCap(collId, type(uint128).max);
        vault.increaseRelativeCap(collId, 1e18);

        bytes memory mktId = abi.encode("this/marketParams", adapter, marketParams);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (mktId, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (mktId, 1e18)));
        vault.increaseAbsoluteCap(mktId, type(uint128).max);
        vault.increaseRelativeCap(mktId, 1e18);

        // Vault dead deposit → allocates into RSS/USDC via liquidityAdapter
        IERC20(USDC).approve(address(vault), DEAD);
        vault.deposit(DEAD, address(0xdead));

        // Final ownership → landing wallet; keep deployer as curator/allocator for ops on fork
        vault.setCurator(deployer);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (LANDING, true)));
        vault.setIsAllocator(LANDING, true);
        vault.setOwner(LANDING);

        vm.stopPrank();

        console.log("VaultV2", address(vault));
        console.log("Adapter", adapter);
        console.log("Owner(landing)", vault.owner());
    }

    function _setForceDeallocatePenalty() internal {
        vm.startPrank(deployer); // curator
        vault.submit(abi.encodeCall(IVaultV2.setForceDeallocatePenalty, (adapter, PENALTY)));
        vault.setForceDeallocatePenalty(adapter, PENALTY);
        vm.stopPrank();
        assertEq(vault.forceDeallocatePenalty(adapter), PENALTY);
    }

    /// @dev Deposit → allocate → borrow market to ~100% util → prove normal withdraw reverts,
    ///      then flash-style supply + forceDeallocate + withdraw to landing.
    function _oneExitRound(uint256 assets, address depositor) internal {
        // Isolate landing balance for this round's assert (fork may already hold dust).
        deal(USDC, LANDING, 0);

        // deposit + simulated flash refill (flash size = full market drain, not just deposit)
        deal(USDC, depositor, assets);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(vault), assets);
        vault.deposit(assets, depositor);
        vm.stopPrank();

        // Ensure liquidity is in market (liquidityAdapter may already auto-allocate on deposit)
        uint256 idle = IERC20(USDC).balanceOf(address(vault));
        if (idle > 0) {
            vm.prank(deployer);
            vault.allocate(adapter, abi.encode(marketParams), idle);
        }

        // Drain THIS market to ~100% util (not Morpho global cash — other markets sit there too).
        Market memory mkt = IMorpho(MORPHO).market(Id.wrap(MARKET_ID));
        uint256 available = uint256(mkt.totalSupplyAssets) - uint256(mkt.totalBorrowAssets);
        require(available >= assets, "market liquidity too thin");

        // Leave $1 dust so shares math stays healthy; borrow the rest.
        uint256 toBorrow = available - 1e6;
        // RSS @ ~$1, 77% LLTV → coll >= toBorrow/0.77. Use 2× cushion; USDC 6dp → RSS 18dp.
        uint256 coll = toBorrow * 2 * 1e12;
        deal(RSS, borrower, coll);

        vm.startPrank(borrower);
        IERC20(RSS).approve(MORPHO, coll);
        IMorpho(MORPHO).supplyCollateral(marketParams, coll, borrower, hex"");
        IMorpho(MORPHO).borrow(marketParams, toBorrow, 0, borrower, borrower);
        vm.stopPrank();

        mkt = IMorpho(MORPHO).market(Id.wrap(MARKET_ID));
        assertLe(uint256(mkt.totalSupplyAssets) - uint256(mkt.totalBorrowAssets), 1e6, "market not drained");

        // Normal withdraw must fail at ~100% util (no free market cash)
        vm.prank(depositor);
        vm.expectRevert();
        vault.withdraw(assets, LANDING, depositor);

        // In-kind exit: simulated flashloan supply → forceDeallocate → withdraw (penalty burned)
        uint256 penalty = (assets * PENALTY + WAD - 1) / WAD; // mulDivUp
        uint256 withdrawable = assets - penalty;

        deal(USDC, depositor, assets); // flash refill
        vm.startPrank(depositor);
        IERC20(USDC).approve(MORPHO, assets);
        IMorpho(MORPHO).supply(marketParams, assets, 0, depositor, hex"");
        vault.forceDeallocate(adapter, abi.encode(marketParams), assets, depositor);
        vault.withdraw(withdrawable, LANDING, depositor);
        vm.stopPrank();

        // Flash repay would consume the Morpho supply position; landing holds liquid USDC
        assertEq(IERC20(USDC).balanceOf(LANDING), withdrawable, "landing USDC");
        console.log("exitRound ok assets", assets);
        console.log("borrowedToDrain", toBorrow);
        console.log("landing received", withdrawable);
    }

    function test_ForceDeallocateExit_Twice_AtFullUtil() public {
        // Round 1
        _oneExitRound(10_000e6, makeAddr("depositor1"));

        // Round 2 — fresh depositor, same vault, again at 100% util
        // Repay prior borrower debt so market can be re-drained cleanly for second seed
        uint256 debt = IMorpho(MORPHO).expectedBorrowAssets(marketParams, borrower);
        if (debt > 0) {
            deal(USDC, borrower, debt + 1e6);
            vm.startPrank(borrower);
            IERC20(USDC).approve(MORPHO, debt + 1e6);
            IMorpho(MORPHO).repay(marketParams, debt, 0, borrower, hex"");
            vm.stopPrank();
        }

        _oneExitRound(25_000e6, makeAddr("depositor2"));

        assertEq(vault.owner(), LANDING, "owner stays landing");
        console.log("PASS forceDeallocate x2 at 100% util; owner=landing");
    }

    function test_DeployedStack_RolesAndPenalty() public view {
        assertEq(vault.asset(), USDC);
        assertEq(vault.owner(), LANDING);
        assertEq(vault.curator(), deployer);
        assertTrue(vault.isAllocator(deployer));
        assertTrue(vault.isAllocator(LANDING));
        assertEq(vault.forceDeallocatePenalty(adapter), PENALTY);
        assertEq(IMorphoMarketV1AdapterV2(adapter).adaptiveCurveIrm(), ADAPTIVE_CURVE_IRM);
        assertEq(IMorphoMarketV1AdapterV2(adapter).parentVault(), address(vault));
    }
}
