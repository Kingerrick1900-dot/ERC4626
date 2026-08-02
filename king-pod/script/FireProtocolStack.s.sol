// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanAsyncVault} from "../src/stack/CrownElepanAsyncVault.sol";
import {CrownPsmIntentSettlement} from "../src/stack/CrownPsmIntentSettlement.sol";
import {CrownEle77PoRFeed, CrownGoldCdpPoRFeed} from "../src/stack/CrownChainlinkPoR.sol";
import {CrownEusdV4Hook} from "../src/stack/CrownEusdV4Hook.sol";
import {CrownCrossChainSettlement} from "../src/stack/CrownCrossChainSettlement.sol";

/// @notice Deploy 5-layer Base ↔ Scroll protocol automation stack.
/// @dev SCROLL: KING_GO=1 FIRE_STACK_SCROLL=1 forge script … --rpc-url $SCROLL_RPC --broadcast
///      BASE:   KING_GO=1 FIRE_STACK_BASE=1   forge script … --rpc-url $BASE_RPC_URL --broadcast
contract FireProtocolStack is Script {
    // Scroll live
    address constant SCROLL_PSM = 0x064489A287448674AA1dC6fb740d2F518CBA75dA;
    address constant SCROLL_EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant SCROLL_USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant SCROLL_GOLD_CDP = 0x6876E987F8C9d9e661068C610D9290Df41D4889f;
    address constant SCROLL_EUSD_LINK = 0xb7b1EfC8621764BeF097a34cD22B75Ac0706A7b6;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;

    // Base live
    address constant BASE_EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BASE_HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant BASE_EUSD_LINK = 0x860E508DD874a8046329b314fD5311567DB8516D;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant V4_POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    // LayerZero Endpoint V2 Base / Scroll (canonical)
    address constant LZ_BASE = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant LZ_SCROLL = 0x1a44076050125825900e736c501f859c50fE728c;

    uint64 constant CHAIN_SCROLL = 534352;
    uint64 constant CHAIN_BASE = 8453;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        bool fireScroll = vm.envOr("FIRE_STACK_SCROLL", uint256(0)) == 1;
        bool fireBase = vm.envOr("FIRE_STACK_BASE", uint256(0)) == 1;
        require(fireScroll || fireBase, "NEED FIRE_STACK_SCROLL=1 or FIRE_STACK_BASE=1");

        if (fireScroll) _deployScroll();
        if (fireBase) _deployBase();
    }

    function _deployScroll() internal {
        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == SCROLL_HOT, "SCROLL_HOT");

        vm.startBroadcast(pk);

        // 1. ERC-7540
        CrownElepanAsyncVault vault = new CrownElepanAsyncVault(SCROLL_PSM, SCROLL_HOT);
        console2.log("L1_ERC7540_VAULT", address(vault));

        // 2. ERC-7683
        CrownPsmIntentSettlement settle =
            new CrownPsmIntentSettlement(address(vault), SCROLL_USDC, CHAIN_SCROLL, CHAIN_BASE, SCROLL_HOT);
        vault.setOperator(address(settle), true);
        console2.log("L2_ERC7683_SETTLEMENT", address(settle));

        // 3. Chainlink PoR — Gold CDP
        CrownGoldCdpPoRFeed goldPor = new CrownGoldCdpPoRFeed(SCROLL_GOLD_CDP, SCROLL_HOT);
        console2.log("L3_GOLD_CDP_POR", address(goldPor));

        // 5. Cross-chain settlement (Scroll side)
        CrownCrossChainSettlement xchain = new CrownCrossChainSettlement(SCROLL_EUSD, SCROLL_HOT);
        xchain.setEndpoints(address(0), LZ_SCROLL, address(0), SCROLL_EUSD_LINK);
        console2.log("L5_XCHAIN_SCROLL", address(xchain));

        vm.stopBroadcast();

        console2.log("STACK_SCROLL_OK", uint256(1));
    }

    function _deployBase() internal {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == BASE_HOT, "BASE_HOT");

        vm.startBroadcast(pk);

        // 3. Chainlink PoR — ELE77
        CrownEle77PoRFeed elePor = new CrownEle77PoRFeed(MORPHO, ELE77, YELE, BASE_HOT);
        console2.log("L3_ELE77_POR", address(elePor));

        // 4. Uniswap v4 eUSD price hook
        CrownEusdV4Hook hook = new CrownEusdV4Hook(V4_POOL_MANAGER, BASE_EUSD, BASE_USDC, BASE_HOT);
        console2.log("L4_V4_EUSD_HOOK", address(hook));

        // 5. Cross-chain settlement (Base side)
        CrownCrossChainSettlement xchain = new CrownCrossChainSettlement(BASE_EUSD, BASE_HOT);
        xchain.setEndpoints(address(0), LZ_BASE, BASE_EUSD_LINK, address(0));
        console2.log("L5_XCHAIN_BASE", address(xchain));

        vm.stopBroadcast();

        console2.log("STACK_BASE_OK", uint256(1));
    }
}
