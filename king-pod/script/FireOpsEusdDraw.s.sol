// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownOpsEusdDraw} from "../src/CrownOpsEusdDraw.sol";

interface IEusdOwnerOps {
    function owner() external view returns (address);
    function setMinter(address minter, bool allowed) external;
    function isMinter(address) external view returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy + optional Bound-capped eUSD ops draw to Landing.
/// @dev FIRE_OPS_EUSD=1 to broadcast. DRAW_EUSD set to mint amount (18dp). 0 = deploy/wire only.
contract FireOpsEusdDraw is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    uint256 constant LLTV_70 = 7e17;

    function run() external {
        require(vm.envOr("FIRE_OPS_EUSD", uint256(0)) == 1, "NEED FIRE_OPS_EUSD=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address drawer = vm.envOr("OPS_DRAWER", address(0));
        uint256 drawAmt = vm.envOr("DRAW_EUSD", uint256(0));

        vm.startBroadcast(pk);

        CrownOpsEusdDraw ops;
        if (drawer == address(0)) {
            ops = new CrownOpsEusdDraw(GATE, EUSD, HOT, LAND, LLTV_70);
            console2.log("OPS_DRAWER", address(ops));
        } else {
            ops = CrownOpsEusdDraw(drawer);
            console2.log("OPS_DRAWER_REUSE", drawer);
        }

        if (!IEusdOwnerOps(EUSD).isMinter(address(ops))) {
            require(IEusdOwnerOps(EUSD).owner() == HOT, "EUSD_OWNER");
            IEusdOwnerOps(EUSD).setMinter(address(ops), true);
            console2.log("MINTER_SET", uint256(1));
        }

        console2.log("maxDraw", ops.maxDraw());
        console2.log("drawn", ops.drawnEusd());
        console2.log("land_eusd_before", IEusdOwnerOps(EUSD).balanceOf(LAND));

        if (drawAmt > 0) {
            ops.draw(drawAmt);
            console2.log("DREW", drawAmt);
        } else {
            console2.log("DEPLOY_WIRE_ONLY", uint256(1));
        }

        console2.log("land_eusd_after", IEusdOwnerOps(EUSD).balanceOf(LAND));
        console2.log("OPS_EUSD_OK", uint256(1));
        vm.stopBroadcast();
    }
}
