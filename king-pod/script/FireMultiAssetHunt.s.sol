// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownMultiAssetHunter} from "../src/CrownMultiAssetHunter.sol";

interface IHuntAdmin {
    function setTarget(address t, bool ok) external;
    function setHunter(address h, bool ok) external;
    function killSwitch() external view returns (bool);
    function hunter(address) external view returns (bool);
    function targetOk(address) external view returns (bool);
    function hunt(address, uint256, address[] calldata, uint256[] calldata, bytes[] calldata, uint256)
        external
        payable;
}

/// @notice Fire Multi-Asset Hunt — allowlist DEX targets, deploy bot, smoke WETH/cbBTC/USDC.
contract FireMultiAssetHunt is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant HUNT = 0xc4c63f8CD4182452f665e338F87b4d31aeF04516;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // Base DEX / venue targets for future arb calldata
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant UNI_SWAP_ROUTER02 = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant AERO_ROUTER_V2 = 0x6Cb442acF35158D5eDa88fe602221b67B400Be3E;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        IHuntAdmin hunt = IHuntAdmin(HUNT);
        // Targets = call venues inside flash (not the flash tokens themselves)
        hunt.setTarget(AERO_ROUTER, true);
        hunt.setTarget(UNI_SWAP_ROUTER02, true);
        hunt.setTarget(AERO_ROUTER_V2, true);

        CrownMultiAssetHunter bot = new CrownMultiAssetHunter(HUNT, HOT, WETH, CBBTC, USDC, HOT);
        hunt.setHunter(address(bot), true);
        // HOT remains hunter for direct ops
        hunt.setHunter(HOT, true);

        // Smoke multi-asset flash pipes (empty path, Morpho 0-fee)
        bot.smoke(WETH, 0.01 ether);
        bot.smoke(CBBTC, 1e5); // 0.001 cbBTC (8dp)
        bot.smoke(USDC, 1e6); // $1

        vm.stopBroadcast();

        console2.log("bot", address(bot));
        console2.log("killSwitch", hunt.killSwitch());
        console2.log("hunterBot", hunt.hunter(address(bot)));
        console2.log("aero", hunt.targetOk(AERO_ROUTER));
        console2.log("uni", hunt.targetOk(UNI_SWAP_ROUTER02));
        console2.log("aeroV2", hunt.targetOk(AERO_ROUTER_V2));
    }
}
