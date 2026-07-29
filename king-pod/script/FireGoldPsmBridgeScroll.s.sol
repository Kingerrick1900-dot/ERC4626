// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldParityPsm} from "../src/scroll/CrownGoldParityPsm.sol";
import {CrownScrollEusdLink} from "../src/scroll/CrownScrollEusdLink.sol";

interface IEusdM {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
    function owner() external view returns (address);
}

/// @notice Deploy Scroll gold rail PSM + Base↔Scroll eUSD link. KING_GO=1 FIRE_GOLD_RAIL=1
contract FireGoldPsmBridgeScroll is Script {
    address constant HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant LAND = 0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f;
    address constant EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant KXAU = 0x156d912F37C179798D8396Da5d58919FA634262d;
    address constant ORACLE = 0xccB83516c5E9c557B9407ABF00865fe516B4a8c8; // $10 gold

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_GOLD_RAIL", uint256(0)) == 1, "NEED FIRE_GOLD_RAIL=1");
        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IEusdM(EUSD).owner() == HOT, "EUSD_OWNER");

        vm.startBroadcast(pk);

        CrownGoldParityPsm psm = new CrownGoldParityPsm(EUSD, USDC, KXAU, ORACLE, LAND, HOT);
        CrownScrollEusdLink link = new CrownScrollEusdLink(EUSD, LAND, HOT);

        IEusdM(EUSD).setMinter(address(psm), true);
        IEusdM(EUSD).setMinter(address(link), true);

        vm.stopBroadcast();

        console2.log("goldPsm", address(psm));
        console2.log("scrollLink", address(link));
        console2.log("psmMinter", IEusdM(EUSD).isMinter(address(psm)) ? uint256(1) : uint256(0));
        console2.log("linkMinter", IEusdM(EUSD).isMinter(address(link)) ? uint256(1) : uint256(0));
        console2.log("GOLD_RAIL_SCROLL_OK", uint256(1));
    }
}
