// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IPublicAllocator700 {
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
}

/// @notice Step 2 — formalize King yRSS PA flow caps at $700k maxIn (RSS) / $700k maxOut (cbBTC+WETH sources).
contract SetPa700k is Script {
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YVAULT = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant RSS = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint128 constant CAP_700K = 700_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        IPublicAllocator700.FlowCapsConfig[] memory caps = new IPublicAllocator700.FlowCapsConfig[](3);
        // RSS: receive up to $700k via PA
        caps[0] = IPublicAllocator700.FlowCapsConfig({
            id: RSS, caps: IPublicAllocator700.FlowCaps({maxIn: CAP_700K, maxOut: CAP_700K})
        });
        // Source books: allow $700k out toward RSS
        caps[1] = IPublicAllocator700.FlowCapsConfig({
            id: CBBTC, caps: IPublicAllocator700.FlowCaps({maxIn: CAP_700K, maxOut: CAP_700K})
        });
        caps[2] = IPublicAllocator700.FlowCapsConfig({
            id: WETH, caps: IPublicAllocator700.FlowCaps({maxIn: CAP_700K, maxOut: CAP_700K})
        });

        vm.startBroadcast(pk);
        IPublicAllocator700(PA).setFlowCaps(YVAULT, caps);
        vm.stopBroadcast();

        (uint128 rssIn, uint128 rssOut) = IPublicAllocator700(PA).flowCaps(YVAULT, RSS);
        console2.log("RSS maxIn", uint256(rssIn));
        console2.log("RSS maxOut", uint256(rssOut));
        require(rssIn == CAP_700K, "MAXIN");
    }
}
