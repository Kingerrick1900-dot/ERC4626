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
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IYrssFire {
    function totalAssets() external view returns (uint256);
}

/// @notice Reuse live forge — no redeploy. FIRE_PATH_B_STAGE=1 · ZK_SHIELD=1 · HOT_KEY · FORGE_ADDR · ASK_USDC · LOOPS
contract FirePathBStageYrss is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant EUSD_MKT = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;

    function run() external {
        require(vm.envOr("FIRE_PATH_B_STAGE", uint256(0)) == 1, "FIRE_PATH_B_STAGE");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address forgeAddr = vm.envAddress("FORGE_ADDR");
        CrownPathBYrssIdle forge_ = CrownPathBYrssIdle(forgeAddr);
        require(forge_.owner() == HOT, "NOT_OWNER");
        require(IMorphoFire(MORPHO).isAuthorized(HOT, forgeAddr), "NO_AUTH");

        uint256 ask = vm.envOr("ASK_USDC", uint256(10_000_000e6));
        uint256 loops = vm.envOr("LOOPS", uint256(1));
        uint256 before = IYrssFire(YRSS).totalAssets();
        uint256 forgedBefore = forge_.totalForged();

        vm.startBroadcast(pk);
        IEusdFire(EUSD).setMinter(forgeAddr, true);
        for (uint256 i; i < loops; ++i) {
            forge_.forge(ask);
        }
        IEusdFire(EUSD).setMinter(forgeAddr, false);
        vm.stopBroadcast();

        (uint256 shares,,) = IMorphoFire(MORPHO).position(EUSD_MKT, YRSS);
        uint256 after_ = IYrssFire(YRSS).totalAssets();
        uint256 forgedAfter = forge_.totalForged();
        console2.log("FORGE", forgeAddr);
        console2.log("ASK", ask);
        console2.log("LOOPS", loops);
        console2.log("YRSS_BEFORE", before);
        console2.log("YRSS_AFTER", after_);
        console2.log("YRSS_EUSD_MKT_SHARES", shares);
        console2.log("FORGED_BEFORE", forgedBefore);
        console2.log("FORGED_AFTER", forgedAfter);
        require(after_ + 1e6 >= before + ask * loops, "TVL");
        require(forgedAfter == forgedBefore + ask * loops, "FORGED");
        require(shares > 0, "SHARES");
        require(!IEusdFire(EUSD).isMinter(forgeAddr), "MINTER_LEFT_ON");
    }
}
