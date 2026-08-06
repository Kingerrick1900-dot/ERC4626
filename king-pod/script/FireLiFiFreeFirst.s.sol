// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLiFiFreeFirst} from "../src/CrownLiFiFreeFirst.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoS {
    function setAuthorization(address, bool) external;
}

/// @notice Live free-first LI.FI fire. Env: PRIVATE_KEY, USDC_FLASH, optional EXTRA_RSS, LANDING_USDC, MACHINE.
contract FireLiFiFreeFirst is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        uint256 flash = vm.envUint("USDC_FLASH");
        uint256 extraRss = vm.envOr("EXTRA_RSS", uint256(0));
        uint256 landingUsdc = vm.envOr("LANDING_USDC", uint256(0));

        uint256 before_ = IERC20S(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        address machineAddr = vm.envOr("MACHINE", address(0));
        CrownLiFiFreeFirst m;
        if (machineAddr == address(0)) {
            m = new CrownLiFiFreeFirst(MORPHO, USDC, RSS, HOT, LANDING, MID);
            IMorphoS(MORPHO).setAuthorization(address(m), true);
        } else {
            m = CrownLiFiFreeFirst(machineAddr);
        }
        if (extraRss > 0) IERC20S(RSS).approve(address(m), extraRss);
        m.runFreeFirst(flash, extraRss, landingUsdc);
        vm.stopBroadcast();

        console2.log("MACHINE", address(m));
        console2.log("LANDING_BEFORE", before_);
        console2.log("LANDING_AFTER", IERC20S(USDC).balanceOf(LANDING));
        console2.log("DELTA", IERC20S(USDC).balanceOf(LANDING) - before_);
        console2.log("FLASH", m.lastFlash());
        console2.log("BORROW", m.lastBorrow());
        console2.log("IDLE", m.lastIdle());
        console2.log("CREDIT", m.lastLandingCredit());
        console2.log("MODE", m.lastMode());
    }
}
