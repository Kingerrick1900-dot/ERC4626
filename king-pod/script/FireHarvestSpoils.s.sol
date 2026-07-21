// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20H {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IYrssH {
    function feeRecipient() external view returns (address);
    function setFeeRecipient(address) external;
}

/// @notice Harvest spoils: fee recipient -> Landing, sweep hot USDC dust -> Landing.
/// @dev KING_OK=1 FIRE_HARVEST=1
contract FireHarvestSpoils is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("FIRE_HARVEST", uint256(0)) == 1, "FIRE_HARVEST");

        uint256 landBefore = IERC20H(USDC).balanceOf(LANDING);
        address recipient = IYrssH(YRSS).feeRecipient();

        vm.startBroadcast(pk);
        if (recipient != LANDING) {
            IYrssH(YRSS).setFeeRecipient(LANDING);
        }
        uint256 hotUsdc = IERC20H(USDC).balanceOf(HOT);
        if (hotUsdc > 0) {
            IERC20H(USDC).transfer(LANDING, hotUsdc);
        }
        vm.stopBroadcast();

        uint256 landAfter = IERC20H(USDC).balanceOf(LANDING);
        console2.log("feeRecipientNow", IYrssH(YRSS).feeRecipient());
        console2.log("landingGain", landAfter - landBefore);
        console2.log("HARVEST_OK", uint256(1));
    }
}
