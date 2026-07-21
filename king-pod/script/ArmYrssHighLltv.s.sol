// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoArmH {
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
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
}

interface IPublicAllocatorArmH {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
}

/// @notice Enable King's high-LLTV RSS market on yRSS + PA caps + queue priority.
/// @dev KING_OK=1 + FIRE_ARM=1 to broadcast.
contract ArmYrssHighLltv is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YVAULT = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant ORACLE_RSS = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant ORACLE_BRETT = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    bytes32 constant CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_625 = 625000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;
    uint256 constant CAP = 14_000_000e6;
    uint256 constant PA_DEFAULT = 700_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "LIVE-FIRE-LAW: need KING_OK=1");
        bool doFire = vm.envOr("FIRE_ARM", uint256(0)) == 1;
        uint256 highLltv = vm.envOr("HIGH_LLTV", LLTV_915);
        uint256 paCap = vm.envOr("PA_CAP", PA_DEFAULT);

        IMetaMorphoArmH.MarketParams memory rssHi = IMetaMorphoArmH.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE_RSS,
            irm: IRM,
            lltv: highLltv
        });
        bytes32 idHi = keccak256(abi.encode(rssHi));

        console2.log("=== ARM yRSS HIGH-LLTV ===");
        console2.logBytes32(idHi);
        console2.log("paCap", paCap);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        if (!doFire) {
            console2.log("DRY: would submitCap/acceptCap/setQueue/setFlowCaps");
            console2.log("READY", uint256(0));
            return;
        }

        vm.startBroadcast(pk);
        IMetaMorphoArmH(YVAULT).submitCap(rssHi, CAP);
        IMetaMorphoArmH(YVAULT).acceptCap(rssHi);

        bytes32[] memory queue = new bytes32[](5);
        queue[0] = idHi; // King's high-LLTV first
        queue[1] = RSS77;
        queue[2] = BRETT_M;
        queue[3] = CBBTC;
        queue[4] = WETH;
        IMetaMorphoArmH(YVAULT).setSupplyQueue(queue);

        IPublicAllocatorArmH.FlowCapsConfig[] memory caps = new IPublicAllocatorArmH.FlowCapsConfig[](3);
        caps[0] = IPublicAllocatorArmH.FlowCapsConfig({
            id: idHi,
            caps: IPublicAllocatorArmH.FlowCaps({maxIn: uint128(paCap), maxOut: uint128(paCap)})
        });
        caps[1] = IPublicAllocatorArmH.FlowCapsConfig({
            id: RSS77,
            caps: IPublicAllocatorArmH.FlowCaps({maxIn: uint128(paCap), maxOut: uint128(paCap)})
        });
        caps[2] = IPublicAllocatorArmH.FlowCapsConfig({
            id: BRETT_M,
            caps: IPublicAllocatorArmH.FlowCaps({maxIn: uint128(paCap), maxOut: uint128(paCap)})
        });
        IPublicAllocatorArmH(PA).setFlowCaps(YVAULT, caps);
        vm.stopBroadcast();

        (uint184 c,,) = IMetaMorphoArmH(YVAULT).config(idHi);
        console2.log("highLltvCap", uint256(c));
        console2.log("ARMED");
        console2.log("READY", uint256(1));
    }
}
