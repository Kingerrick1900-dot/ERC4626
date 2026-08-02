// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";
import {CrownChainlinkXauOracle} from "src/CrownChainlinkXauOracle.sol";
contract DeployXauRef is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CrownChainlinkXauOracle o = new CrownChainlinkXauOracle(0x5213eBB69743b85644dbB6E25cdF994aFBb8cF31, 1 days);
        console2.log("xauRef", address(o));
        console2.log("price", o.price());
        vm.stopBroadcast();
    }
}
