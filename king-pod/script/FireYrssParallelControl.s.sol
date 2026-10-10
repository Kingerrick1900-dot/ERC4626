// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoY {
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
    function setCurator(address newCurator) external;
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function supplyQueue(uint256) external view returns (bytes32);
    function supplyQueueLength() external view returns (uint256);
    function withdrawQueueLength() external view returns (uint256);
    function isAllocator(address) external view returns (bool);
    function curator() external view returns (address);
    function owner() external view returns (address);
}

interface IPublicAllocatorY {
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

/// @notice Seize yRSS command surface: enable parallel 38.5% market, queue it first, PA caps, Safe allocator+curator.
/// @dev Gate: FIRE_YRSS_PARALLEL_CONTROL=1 · HOT_KEY (yRSS owner). Legacy SOV book untouched.
contract FireYrssParallelControl is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant SOV_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    bytes32 constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    bytes32 constant IDLE_CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_MKT = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant LEGACY = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint256 constant PARALLEL_LLTV = 385000000000000000;
    uint256 constant CAP = 50_000_000e6; // $50M — match sovereign rail

    function run() external {
        require(vm.envOr("FIRE_YRSS_PARALLEL_CONTROL", uint256(0)) == 1, "FIRE_YRSS_PARALLEL_CONTROL");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IMetaMorphoY(YRSS).owner() == HOT, "NOT_YRSS_OWNER");
        require(IPublicAllocatorY(PA).admin(YRSS) == HOT, "NOT_PA_ADMIN");

        IMetaMorphoY.MarketParams memory parMp =
            IMetaMorphoY.MarketParams(USDC, RSS, SOV_ORACLE, IRM, PARALLEL_LLTV);
        require(keccak256(abi.encode(parMp)) == PAR, "PAR_ID");

        vm.startBroadcast(pk);

        (uint184 existingCap, bool enabled,) = IMetaMorphoY(YRSS).config(PAR);
        if (!enabled || uint256(existingCap) < CAP) {
            IMetaMorphoY(YRSS).submitCap(parMp, CAP);
            IMetaMorphoY(YRSS).acceptCap(parMp);
            console2.log("PAR_CAP_ARMED", CAP);
        } else {
            console2.log("PAR_CAP_ALREADY", uint256(existingCap));
        }

        // Supply queue: parallel first — new USDC charges the King's empty rail.
        bytes32[] memory queue = new bytes32[](5);
        queue[0] = PAR;
        queue[1] = SOV;
        queue[2] = IDLE_CBBTC;
        queue[3] = WETH_MKT;
        queue[4] = LEGACY;
        IMetaMorphoY(YRSS).setSupplyQueue(queue);

        IPublicAllocatorY.FlowCapsConfig[] memory caps = new IPublicAllocatorY.FlowCapsConfig[](1);
        caps[0] = IPublicAllocatorY.FlowCapsConfig({
            id: PAR,
            caps: IPublicAllocatorY.FlowCaps({maxIn: uint128(CAP), maxOut: uint128(CAP)})
        });
        IPublicAllocatorY(PA).setFlowCaps(YRSS, caps);

        // Safe gains vault command (allocator + curator). Owner remains HOT for gas ops until Safe takes owner.
        if (!IMetaMorphoY(YRSS).isAllocator(SAFE)) {
            IMetaMorphoY(YRSS).setIsAllocator(SAFE, true);
        }
        if (IMetaMorphoY(YRSS).curator() != SAFE) {
            IMetaMorphoY(YRSS).setCurator(SAFE);
        }

        vm.stopBroadcast();

        (uint184 cap, bool en,) = IMetaMorphoY(YRSS).config(PAR);
        (uint128 maxIn, uint128 maxOut) = IPublicAllocatorY(PA).flowCaps(YRSS, PAR);
        console2.log("YRSS", YRSS);
        console2.log("PAR_ENABLED", en ? uint256(1) : uint256(0));
        console2.log("PAR_CAP", uint256(cap));
        console2.log("PAR_maxIn", uint256(maxIn));
        console2.log("PAR_maxOut", uint256(maxOut));
        console2.log("supplyQueue0");
        console2.logBytes32(IMetaMorphoY(YRSS).supplyQueue(0));
        console2.log("curator", IMetaMorphoY(YRSS).curator());
        console2.log("allocatorSafe", IMetaMorphoY(YRSS).isAllocator(SAFE) ? uint256(1) : uint256(0));
        console2.log("allocatorHOT", IMetaMorphoY(YRSS).isAllocator(HOT) ? uint256(1) : uint256(0));
        console2.log("withdrawQueueLen", IMetaMorphoY(YRSS).withdrawQueueLength());
        console2.log("MISSION yRSS parallel control armed");
    }
}
