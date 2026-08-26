// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";
import {CrownZkMesh} from "../src/zk/CrownZkMesh.sol";

interface IERC20M {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract FireV4ScrollLean is Script {
    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "GO");
        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        address hot = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
        require(vm.addr(pk) == hot, "HOT");

        address eusd = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
        address usdc = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
        address psm = 0x064489A287448674AA1dC6fb740d2F518CBA75dA;
        address por = 0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59;

        uint256 step = vm.envOr("STEP", uint256(1));
        vm.startBroadcast(pk);
        if (step == 1) {
            CrownGoldUsd g = new CrownGoldUsd(eusd, por, hot);
            console2.log("gUSD", address(g));
        } else if (step == 2) {
            address gusd = vm.envAddress("GUSD");
            CrownSyncRedeem8020 s = new CrownSyncRedeem8020(eusd, gusd, psm, usdc, hot);
            console2.log("sync8020", address(s));
        } else if (step == 3) {
            address gusd = vm.envAddress("GUSD");
            uint256 amt = 1000e18;
            IERC20M(eusd).approve(gusd, amt);
            CrownGoldUsd(gusd).wrap(amt, hot);
            console2.log("wrapped", amt);
        } else if (step == 4) {
            CrownZkMesh m = new CrownZkMesh(hot);
            m.wire(534352, 0xab2856626BBd8E6fba9dB93783029eB973E8427F, 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30, 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637);
            m.wire(8453, 0xab2856626BBd8E6fba9dB93783029eB973E8427F, 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30, 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637);
            console2.log("mesh", address(m));
        }
        vm.stopBroadcast();
    }
}
