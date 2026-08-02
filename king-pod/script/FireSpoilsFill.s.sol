// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSpoilsFill} from "../src/CrownSpoilsFill.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorpho {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
}

/// @notice Deploy + arm permissionless TEN spoil fill. KING_GO=1 FIRE_SPOILS_FILL=1
/// @dev Lists hot ELE for USDC ask (≥ TEN debt). Filler unlocks ~$700k spoil to hot.
contract FireSpoilsFill is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SPOILS_FILL", uint256(0)) == 1, "NEED FIRE_SPOILS_FILL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 eleBal = IERC20(ELE).balanceOf(HOT);
        uint256 eleList = vm.envOr("ELE_LIST", eleBal);
        require(eleList > 0 && eleList <= eleBal, "ELE");

        CrownSpoilsFill fill = CrownSpoilsFill(vm.envOr("SPOILS_FILL", address(0)));

        vm.startBroadcast(pk);
        if (address(fill) == address(0) || address(fill).code.length == 0) {
            fill = new CrownSpoilsFill(HOT, ORACLE_10);
            console2.log("deployed", address(fill));
        }

        if (!IMorpho(MORPHO).isAuthorized(HOT, address(fill))) {
            IMorpho(MORPHO).setAuthorization(address(fill), true);
        }

        uint256 ask = vm.envOr("USDC_ASK", uint256(0));
        if (ask == 0) {
            uint256 d = fill.debt();
            ask = d + 1e6; // $1 buffer over debt
        }
        bool pullColl = vm.envOr("PULL_TEN_COLL", uint256(0)) == 1;

        IERC20(ELE).approve(address(fill), eleList);
        fill.list(eleList, ask, pullColl);
        vm.stopBroadcast();

        console2.log("SPOILS_FILL", address(fill));
        console2.log("eleListed", fill.eleListed());
        console2.log("usdcAsk", fill.usdcAsk());
        console2.log("debt", fill.debt());
        console2.log("SPOILS_FILL_ARMED", uint256(1));
    }
}
