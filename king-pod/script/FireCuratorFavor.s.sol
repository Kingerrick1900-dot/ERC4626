// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoFavor {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(MarketParams memory marketParams) external;
    function setSupplyQueue(bytes32[] calldata ids) external;
    function setIsAllocator(address allocator, bool isAllocator) external;
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function supplyQueueLength() external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
    function isAllocator(address) external view returns (bool);
    function curator() external view returns (address);
    function owner() external view returns (address);
}

interface IPublicAllocatorFavor {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
    function admin(address vault) external view returns (address);
}

/// @notice Curator favor pack: idle market + eUSD/USDC first in supply queue + widen PA + Landing allocator.
/// @dev KING_GO=1 forge script script/FireCuratorFavor.s.sol:FireCuratorFavor --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireCuratorFavor is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant RSS40 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant CBBTC_M = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_M = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant BRETT = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    bytes32 constant EUSD_USDC = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;
    // Canonical Morpho USDC idle market (coll/oracle/irm/lltv = 0)
    bytes32 constant IDLE = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;

    uint256 constant IDLE_CAP = 50_000_000e6;
    uint128 constant PARK_FLOW = 2_000_000e6;
    uint128 constant BLUE_FLOW = 2_000_000e6;
    uint128 constant IDLE_FLOW = 50_000_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IMetaMorphoFavor(YRSS).owner() == HOT, "NOT_OWNER");
        require(IMetaMorphoFavor(YRSS).curator() == HOT, "NOT_CURATOR");
        require(IPublicAllocatorFavor(PA).admin(YRSS) == HOT, "NOT_PA_ADMIN");

        IMetaMorphoFavor.MarketParams memory idleMp = IMetaMorphoFavor.MarketParams({
            loanToken: USDC,
            collateralToken: address(0),
            oracle: address(0),
            irm: address(0),
            lltv: 0
        });

        vm.startBroadcast(pk);

        // 1) Enable canonical USDC idle market on yRSS
        (, bool idleEnabled,) = IMetaMorphoFavor(YRSS).config(IDLE);
        if (!idleEnabled) {
            IMetaMorphoFavor(YRSS).submitCap(idleMp, IDLE_CAP);
            IMetaMorphoFavor(YRSS).acceptCap(idleMp);
        }

        // 2) Supply queue: eUSD/USDC → idle → park → rest (inbound USDC feeds boss book)
        bytes32[] memory queue = new bytes32[](7);
        queue[0] = EUSD_USDC;
        queue[1] = IDLE;
        queue[2] = PARK;
        queue[3] = RSS40;
        queue[4] = CBBTC_M;
        queue[5] = WETH_M;
        queue[6] = BRETT;
        IMetaMorphoFavor(YRSS).setSupplyQueue(queue);

        // 3) Widen PA doors
        IPublicAllocatorFavor.FlowCapsConfig[] memory caps = new IPublicAllocatorFavor.FlowCapsConfig[](4);
        caps[0] = IPublicAllocatorFavor.FlowCapsConfig({
            id: PARK, caps: IPublicAllocatorFavor.FlowCaps({maxIn: PARK_FLOW, maxOut: PARK_FLOW})
        });
        caps[1] = IPublicAllocatorFavor.FlowCapsConfig({
            id: CBBTC_M, caps: IPublicAllocatorFavor.FlowCaps({maxIn: BLUE_FLOW, maxOut: BLUE_FLOW})
        });
        caps[2] = IPublicAllocatorFavor.FlowCapsConfig({
            id: WETH_M, caps: IPublicAllocatorFavor.FlowCaps({maxIn: BLUE_FLOW, maxOut: BLUE_FLOW})
        });
        caps[3] = IPublicAllocatorFavor.FlowCapsConfig({
            id: IDLE, caps: IPublicAllocatorFavor.FlowCaps({maxIn: IDLE_FLOW, maxOut: IDLE_FLOW})
        });
        IPublicAllocatorFavor(PA).setFlowCaps(YRSS, caps);

        // 4) Landing allocator
        if (!IMetaMorphoFavor(YRSS).isAllocator(LANDING)) {
            IMetaMorphoFavor(YRSS).setIsAllocator(LANDING, true);
        }

        vm.stopBroadcast();

        console2.log("idle_enabled", idleEnabled || true);
        (uint184 idleCap, bool idleOn,) = IMetaMorphoFavor(YRSS).config(IDLE);
        console2.log("idle_cap", uint256(idleCap));
        console2.log("idle_on", idleOn);
        console2.log("sq0", uint256(uint160(uint256(IMetaMorphoFavor(YRSS).supplyQueue(0))))); // bad cast - just log ids
        console2.logBytes32(IMetaMorphoFavor(YRSS).supplyQueue(0));
        console2.logBytes32(IMetaMorphoFavor(YRSS).supplyQueue(1));
        console2.logBytes32(IMetaMorphoFavor(YRSS).supplyQueue(2));
        (uint128 pIn, uint128 pOut) = IPublicAllocatorFavor(PA).flowCaps(YRSS, PARK);
        (uint128 cIn,) = IPublicAllocatorFavor(PA).flowCaps(YRSS, CBBTC_M);
        (uint128 wIn,) = IPublicAllocatorFavor(PA).flowCaps(YRSS, WETH_M);
        console2.log("park_maxIn", uint256(pIn));
        console2.log("park_maxOut", uint256(pOut));
        console2.log("cbbtc_maxIn", uint256(cIn));
        console2.log("weth_maxIn", uint256(wIn));
        console2.log("landing_allocator", IMetaMorphoFavor(YRSS).isAllocator(LANDING));
    }
}
