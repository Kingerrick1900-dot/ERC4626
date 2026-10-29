// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownPathBYrssIdle} from "../src/CrownPathBYrssIdle.sol";

interface IEusdFire {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
}

interface IMorphoFire {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IYrssFire {
    function totalAssets() external view returns (uint256);
}

/// @notice FIRE_PATH_B_YRSS=1 · ZK_SHIELD=1 · HOT_KEY · ASK_USDC (6dp, default 5M)
contract FirePathBYrssIdle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant EUSD_MKT = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;

    function run() external {
        require(vm.envOr("FIRE_PATH_B_YRSS", uint256(0)) == 1, "FIRE_PATH_B_YRSS");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 ask = vm.envOr("ASK_USDC", uint256(5_000_000e6));
        uint256 before = IYrssFire(YRSS).totalAssets();

        vm.startBroadcast(pk);
        CrownPathBYrssIdle forge_ = new CrownPathBYrssIdle(HOT);
        IEusdFire(EUSD).setMinter(address(forge_), true);
        IMorphoFire(MORPHO).setAuthorization(address(forge_), true);
        forge_.forge(ask);
        // revoke minter after forge (armor)
        IEusdFire(EUSD).setMinter(address(forge_), false);
        vm.stopBroadcast();

        (uint256 shares,,) = IMorphoFire(MORPHO).position(EUSD_MKT, YRSS);
        uint256 after_ = IYrssFire(YRSS).totalAssets();
        console2.log("FORGE", address(forge_));
        console2.log("ASK", ask);
        console2.log("YRSS_BEFORE", before);
        console2.log("YRSS_AFTER", after_);
        console2.log("YRSS_EUSD_MKT_SHARES", shares);
        console2.log("TOTAL_FORGED", forge_.totalForged());
        require(after_ >= before + ask - 1e6, "TVL");
        require(shares > 0, "SHARES");
    }
}
