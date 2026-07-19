// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {IMorphoMarketV1AdapterV2} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams, Id, Market} from "morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from "morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

/// @notice Last tests: prove forceDeallocate exit on the LIVE King Vault V2 (Base), forked.
/// @dev Does not redeploy. Uses on-chain vault/adapter. No broadcast.
contract LiveVaultForceDeallocateExit is Test {
    using MorphoBalancesLib for IMorpho;

    // --- LIVE (Base) ---
    IVaultV2 constant VAULT = IVaultV2(0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9);
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357; // cold owner
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1; // daily curator/allocator

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant PENALTY = 0.01e18;
    uint256 constant WAD = 1e18;

    MarketParams marketParams;
    address borrower = makeAddr("selfBorrower");

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://base-mainnet.public.blastapi.io")));
        marketParams = IMorpho(MORPHO).idToMarketParams(Id.wrap(MARKET_ID));

        // Sanity: live wiring
        require(VAULT.asset() == USDC, "asset");
        require(VAULT.owner() == LANDING, "owner");
        require(VAULT.curator() == HOT, "curator");
        require(VAULT.isAllocator(HOT), "alloc hot");
        require(VAULT.forceDeallocatePenalty(ADAPTER) == PENALTY, "penalty");
        require(IMorphoMarketV1AdapterV2(ADAPTER).parentVault() == address(VAULT), "parent");
        require(VAULT.adapters(0) == ADAPTER, "adapter0");
    }

    function test_LiveRoles_ColdOwner_HotDaily() public view {
        assertEq(VAULT.owner(), LANDING);
        assertEq(VAULT.curator(), HOT);
        assertTrue(VAULT.isAllocator(HOT));
        assertTrue(VAULT.isAllocator(LANDING));
        assertEq(VAULT.forceDeallocatePenalty(ADAPTER), PENALTY);
        console.log("LIVE roles OK; totalAssets", VAULT.totalAssets());
    }

    function _oneExitRound(uint256 assets, address depositor) internal {
        deal(USDC, LANDING, 0);
        deal(USDC, depositor, assets);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(VAULT), assets);
        VAULT.deposit(assets, depositor);
        vm.stopPrank();

        uint256 idle = IERC20(USDC).balanceOf(address(VAULT));
        if (idle > 0) {
            vm.prank(HOT);
            VAULT.allocate(ADAPTER, abi.encode(marketParams), idle);
        }

        Market memory mkt = IMorpho(MORPHO).market(Id.wrap(MARKET_ID));
        uint256 available = uint256(mkt.totalSupplyAssets) - uint256(mkt.totalBorrowAssets);
        require(available >= assets, "thin liquidity");

        uint256 toBorrow = available - 1e6;
        uint256 coll = toBorrow * 2 * 1e12;
        deal(RSS, borrower, coll);

        vm.startPrank(borrower);
        IERC20(RSS).approve(MORPHO, coll);
        IMorpho(MORPHO).supplyCollateral(marketParams, coll, borrower, hex"");
        IMorpho(MORPHO).borrow(marketParams, toBorrow, 0, borrower, borrower);
        vm.stopPrank();

        mkt = IMorpho(MORPHO).market(Id.wrap(MARKET_ID));
        assertLe(uint256(mkt.totalSupplyAssets) - uint256(mkt.totalBorrowAssets), 1e6, "not drained");

        vm.prank(depositor);
        vm.expectRevert();
        VAULT.withdraw(assets, LANDING, depositor);

        uint256 penalty = (assets * PENALTY + WAD - 1) / WAD;
        uint256 withdrawable = assets - penalty;

        deal(USDC, depositor, assets);
        vm.startPrank(depositor);
        IERC20(USDC).approve(MORPHO, assets);
        IMorpho(MORPHO).supply(marketParams, assets, 0, depositor, hex"");
        VAULT.forceDeallocate(ADAPTER, abi.encode(marketParams), assets, depositor);
        VAULT.withdraw(withdrawable, LANDING, depositor);
        vm.stopPrank();

        assertEq(IERC20(USDC).balanceOf(LANDING), withdrawable, "landing USDC");
        console.log("LIVE exitRound ok", assets, "-> landing", withdrawable);
    }

    function test_LiveForceDeallocate_Twice_AtFullUtil() public {
        _oneExitRound(10_000e6, makeAddr("depositor1"));

        uint256 debt = IMorpho(MORPHO).expectedBorrowAssets(marketParams, borrower);
        if (debt > 0) {
            deal(USDC, borrower, debt + 1e6);
            vm.startPrank(borrower);
            IERC20(USDC).approve(MORPHO, debt + 1e6);
            IMorpho(MORPHO).repay(marketParams, debt, 0, borrower, hex"");
            vm.stopPrank();
        }

        _oneExitRound(25_000e6, makeAddr("depositor2"));
        assertEq(VAULT.owner(), LANDING, "owner stays cold landing");
        console.log("PASS LIVE forceDeallocate x2 at 100% util");
    }
}
