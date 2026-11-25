// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFlashRepay} from "../src/CrownFlashRepay.sol";

interface IMorphoA {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IVaultA {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract FireFlashRepay is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant BAL = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YSYNTH = 0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownFlashRepay c = new CrownFlashRepay(BAL, MORPHO, YSYNTH, USDC, EUSD, HOT, ORACLE, IRM, LLTV, HOT);
        if (!IMorphoA(MORPHO).isAuthorized(HOT, address(c))) {
            IMorphoA(MORPHO).setAuthorization(address(c), true);
        }
        uint256 shares = IVaultA(YSYNTH).balanceOf(HOT);
        if (shares > 0) IVaultA(YSYNTH).approve(address(c), shares);
        c.fire();
        vm.stopBroadcast();

        console2.log("CrownFlashRepay", address(c));
        console2.log("hotUsdc", IERC20b(USDC).balanceOf(HOT));
    }
}
