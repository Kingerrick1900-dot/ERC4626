// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorpho1200 {
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

interface IPublicAllocator1200 {
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

/// @notice List RSS/$1200 on yRSS and open PA flow. Phase 2 step 1.
/// @dev KING_OK=1
contract ArmYrss1200 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE_1200 = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;

    bytes32 constant MID_1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant MID_1 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant MID_CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant MID_WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant MID_BRETT = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    uint256 constant CAP = 14_000_000e6;
    uint128 constant FLOW = 700_000e6;

    error NOT_HOT();
    error NO_GO();

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();

        IMetaMorpho1200.MarketParams memory mp =
            IMetaMorpho1200.MarketParams(USDC, RSS, ORACLE_1200, IRM, LLTV);

        vm.startBroadcast(pk);
        IMetaMorpho1200(YRSS).submitCap(mp, CAP);
        IMetaMorpho1200(YRSS).acceptCap(mp);

        bytes32[] memory queue = new bytes32[](5);
        queue[0] = MID_1200;
        queue[1] = MID_1;
        queue[2] = MID_CBBTC;
        queue[3] = MID_WETH;
        queue[4] = MID_BRETT;
        IMetaMorpho1200(YRSS).setSupplyQueue(queue);

        IPublicAllocator1200.FlowCapsConfig[] memory caps = new IPublicAllocator1200.FlowCapsConfig[](3);
        caps[0] = IPublicAllocator1200.FlowCapsConfig({
            id: MID_1200, caps: IPublicAllocator1200.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        caps[1] = IPublicAllocator1200.FlowCapsConfig({
            id: MID_WETH, caps: IPublicAllocator1200.FlowCaps({maxIn: 0, maxOut: FLOW})
        });
        caps[2] = IPublicAllocator1200.FlowCapsConfig({
            id: MID_CBBTC, caps: IPublicAllocator1200.FlowCaps({maxIn: 0, maxOut: FLOW})
        });
        IPublicAllocator1200(PA).setFlowCaps(YRSS, caps);
        vm.stopBroadcast();

        (uint184 cap, bool enabled,) = IMetaMorpho1200(YRSS).config(MID_1200);
        console2.log("rss1200 enabled", enabled);
        console2.log("rss1200 cap", uint256(cap));
        console2.log("ARM_RSS1200_OK", uint256(1));
    }
}
