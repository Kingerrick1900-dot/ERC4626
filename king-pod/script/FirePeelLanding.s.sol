// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Peel kingdom USDC from cold Landing → Hot ops wallet. Not new debit — internal treasury move.
/// @dev Requires LANDING_PRIVATE_KEY (cold wallet). KING_OK=1 KING_GO=1 FIRE_PEEL=1
contract FirePeelLanding is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        require(vm.envOr("FIRE_PEEL", uint256(0)) == 1, "FIRE_PEEL");

        uint256 landingPk = vm.envUint("LANDING_PRIVATE_KEY");
        require(vm.addr(landingPk) == LANDING, "LANDING_PK");

        uint256 peelTarget = vm.envOr("PEEL_TO_HOT", uint256(5_000_000)); // $5 default
        uint256 landReserve = vm.envOr("LAND_RESERVE", uint256(1_000_000)); // keep $1 cold

        uint256 landBal = IERC20P(USDC).balanceOf(LANDING);
        uint256 hotBefore = IERC20P(USDC).balanceOf(HOT);

        console2.log("=== PEEL LANDING -> HOT ===");
        console2.log("landUsdc", landBal);
        console2.log("hotBefore", hotBefore);
        console2.log("peelTarget", peelTarget);
        console2.log("landReserve", landReserve);

        require(landBal > landReserve, "NOTHING TO PEEL");
        uint256 peel = landBal - landReserve;
        if (peel > peelTarget) peel = peelTarget;

        vm.startBroadcast(landingPk);
        require(IERC20P(USDC).transfer(HOT, peel), "TRANSFER");
        vm.stopBroadcast();

        console2.log("peeled", peel);
        console2.log("hotAfter", IERC20P(USDC).balanceOf(HOT));
        console2.log("PEEL_OK", uint256(1));
    }
}
