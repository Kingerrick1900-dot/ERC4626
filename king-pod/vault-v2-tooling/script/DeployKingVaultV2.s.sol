// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {VaultV2} from "vault-v2/VaultV2.sol";
import {VaultV2Factory} from "vault-v2/VaultV2Factory.sol";
import {IVaultV2} from "vault-v2/interfaces/IVaultV2.sol";
import {IMorphoMarketV1AdapterV2} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2.sol";
import {IMorphoMarketV1AdapterV2Factory} from "vault-v2/adapters/interfaces/IMorphoMarketV1AdapterV2Factory.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams, Id} from "morpho-blue/src/interfaces/IMorpho.sol";

/// @notice Live-deploy King private Vault V2 + MorphoMarketV1 adapter for RSS/USDC.
/// @dev OWNER = landing wallet. CURATOR/ALLOCATOR = hot (broadcast signer) so config works
///      after ownership transfer. Timelock 0. Skips Morpho-listing $1M dead deposit.
///      Sets forceDeallocate penalty = 1% for proven 100%-util exit path.
contract DeployKingVaultV2 is Script {
    address constant VAULT_V2_FACTORY = 0x4501125508079A99ebBebCE205DeC9593C2b5857;
    address constant ADAPTER_FACTORY = 0x9a1B378C43BA535cDB89934230F0D3890c51C0EB;
    address constant ADAPTER_REGISTRY = 0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ADAPTIVE_CURVE_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    uint256 constant PENALTY = 0.01e18; // 1%

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        // HARD GATE: no live broadcast until King sets LIVE_ARMED=1
        require(vm.envOr("LIVE_ARMED", uint256(0)) == 1, "NO-LIVE: King must set LIVE_ARMED=1");
        address hot = vm.addr(pk);

        MarketParams memory mp = IMorpho(MORPHO).idToMarketParams(Id.wrap(MARKET_ID));
        require(mp.loanToken == USDC, "loan");
        require(mp.collateralToken == RSS, "coll");
        require(mp.irm == ADAPTIVE_CURVE_IRM, "irm");

        vm.startBroadcast(pk);

        bytes32 salt = keccak256(abi.encodePacked("king-yrss-v2-live", block.timestamp, hot));
        VaultV2 vault = VaultV2(VaultV2Factory(VAULT_V2_FACTORY).createVaultV2(hot, USDC, salt));
        vault.setCurator(hot);

        address adapter = IMorphoMarketV1AdapterV2Factory(ADAPTER_FACTORY).createMorphoMarketV1AdapterV2(address(vault));
        require(IMorphoMarketV1AdapterV2(adapter).adaptiveCurveIrm() == ADAPTIVE_CURVE_IRM, "adapter irm");

        bytes memory adapterIdData = abi.encode("this", adapter);
        vault.submit(abi.encodeCall(vault.setIsAllocator, (hot, true)));
        vault.submit(abi.encodeCall(vault.setIsAllocator, (LANDING, true)));
        vault.submit(abi.encodeCall(vault.setAdapterRegistry, (ADAPTER_REGISTRY)));
        vault.submit(abi.encodeCall(vault.addAdapter, (adapter)));
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (adapterIdData, 1e18)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setAdapterRegistry.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setSendSharesGate.selector)));
        vault.submit(abi.encodeCall(vault.abdicate, (IVaultV2.setReceiveAssetsGate.selector)));

        vault.setAdapterRegistry(ADAPTER_REGISTRY);
        vault.setIsAllocator(hot, true);
        vault.setIsAllocator(LANDING, true);
        vault.addAdapter(adapter);
        vault.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        vault.increaseRelativeCap(adapterIdData, 1e18);
        vault.abdicate(IVaultV2.setAdapterRegistry.selector);
        vault.abdicate(IVaultV2.setReceiveSharesGate.selector);
        vault.abdicate(IVaultV2.setSendSharesGate.selector);
        vault.abdicate(IVaultV2.setReceiveAssetsGate.selector);

        // RSS/USDC market as liquidity destination
        bytes memory liquidityData = abi.encode(mp);
        vault.setLiquidityAdapterAndData(adapter, liquidityData);

        bytes memory collId = abi.encode("collateralToken", mp.collateralToken);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (collId, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (collId, 1e18)));
        vault.increaseAbsoluteCap(collId, type(uint128).max);
        vault.increaseRelativeCap(collId, 1e18);

        bytes memory mktId = abi.encode("this/marketParams", adapter, mp);
        vault.submit(abi.encodeCall(vault.increaseAbsoluteCap, (mktId, type(uint128).max)));
        vault.submit(abi.encodeCall(vault.increaseRelativeCap, (mktId, 1e18)));
        vault.increaseAbsoluteCap(mktId, type(uint128).max);
        vault.increaseRelativeCap(mktId, 1e18);

        // forceDeallocate exit penalty (access path at 100% util)
        vault.submit(abi.encodeCall(IVaultV2.setForceDeallocatePenalty, (adapter, PENALTY)));
        vault.setForceDeallocatePenalty(adapter, PENALTY);

        // Optional tiny dead seed if hot holds >= $1 USDC (NOT Morpho listing-sized 1e12)
        uint256 bal = IERC20(USDC).balanceOf(hot);
        if (bal >= 1e6) {
            IERC20(USDC).approve(address(vault), 1e6);
            vault.deposit(1e6, address(0xdead));
            console.log("tiny dead deposit $1 to 0xdead (private vault; not listing-sized)");
        } else {
            console.log("SKIP dead deposit - insufficient USDC on deployer");
        }

        // Final roles: landing owns; hot remains curator/allocator for ops
        vault.setCurator(hot);
        vault.setOwner(LANDING);

        vm.stopBroadcast();

        console.log("=== KING VAULT V2 LIVE ===");
        console.log("VaultV2", address(vault));
        console.log("Adapter", adapter);
        console.log("Owner(landing)", vault.owner());
        console.log("Curator(hot)", vault.curator());
        console.log("Penalty", vault.forceDeallocatePenalty(adapter));
        console.log("Market", vm.toString(MARKET_ID));
    }
}
