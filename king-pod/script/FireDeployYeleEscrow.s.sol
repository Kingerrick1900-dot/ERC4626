// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";
import {CrownYeleShareEscrow} from "../src/CrownYeleShareEscrow.sol";

contract FireDeployYeleEscrow is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_YELE_ESCROW", uint256(0)) == 1, "NEED FIRE_YELE_ESCROW=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        vm.startBroadcast(pk);
        CrownYeleShareEscrow e = new CrownYeleShareEscrow(YELE, USDC, LANDING, LANDING);
        vm.stopBroadcast();
        console2.log("ESCROW", address(e));
        console2.log("ownerLanding", uint256(1));
        console2.log("YELE_ESCROW_DEPLOY_OK", uint256(1));
    }
}
