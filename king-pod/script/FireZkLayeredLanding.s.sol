// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkLayeredLanding} from "../src/CrownZkLayeredLanding.sol";

/// @notice Deploy / wire ZK-layered Landing ops against LIVE Base flash-bound stack.
/// FIRE=1 broadcasts. REFRESH=1 calls refreshPack (needs hot key + USDC approve on flash).
contract FireZkLayeredLanding is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // LIVE flash-bound stack (PR #88)
    address constant BOUND_GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant CREDIT = 0x20B1513a137b9CB166E2cC15c405e842278E7D1A;
    address constant FLASH = 0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4;
    address constant AUTODRAW = 0x364bEF6c5A3DC2c02D7ECf1e12a2d1F08B0513ba;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        bool refresh = vm.envOr("REFRESH", false);
        address existing = vm.envOr("LAYER", address(0));
        address take = vm.envOr("TAKE", address(0));
        uint256 ask = vm.envOr("ASK_USDC", uint256(700_000e6));

        CrownZkLayeredLanding layer = CrownZkLayeredLanding(existing);

        if (fire) {
            vm.startBroadcast();
            if (address(layer) == address(0)) {
                layer = new CrownZkLayeredLanding(BOUND_GATE, FLASH, CREDIT, AUTODRAW, USDC, HOT, LANDING, ask);
                console2.log("layer", address(layer));
            }
            if (take != address(0)) layer.setWethTake(take);
            if (refresh) {
                (bool proven, uint256 d) = layer.refreshPack(ask);
                console2.log("proven", proven);
                console2.log("flashLandingDelta", d);
            }
            vm.stopBroadcast();
        }

        if (address(layer) == address(0)) {
            console2.log("no LAYER - dry read LIVE gate/credit");
            console2.log("packReady LIVE", IZkGateBook(BOUND_GATE).isProven(HOT));
            console2.log("creditMax LIVE", IZkCreditL(CREDIT).maxBorrow(HOT));
            console2.log("DOCTRINE: 380 WETH is LTV ask not inventory; ZK pack is layer Z");
            return;
        }

        (bool proven, uint256 attest, uint256 creditMax, bool creditOk, bool wethOk, uint256 land) = layer.book();
        console2.log("packReady", proven);
        console2.log("attest", attest);
        console2.log("creditMax", creditMax);
        console2.log("creditOk", creditOk);
        console2.log("wethOk", wethOk);
        console2.log("landingUsdc", land);
        console2.log("DOCTRINE: 380 WETH is LTV ask not inventory; ZK pack is layer Z");
    }
}

interface IZkGateBook {
    function isProven(address) external view returns (bool);
}

interface IZkCreditL {
    function maxBorrow(address) external view returns (uint256);
}
