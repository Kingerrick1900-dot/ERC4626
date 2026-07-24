// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkAutoDraw} from "../src/CrownZkAutoDraw.sol";

/// @notice Deploy permissionless ZK fill→Landing keeper.
/// @dev KING_GO=1 FIRE_ZK_AUTO=1
contract FireDeployZkAutoDraw is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ZK_AUTO", uint256(0)) == 1, "NEED FIRE_ZK_AUTO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        vm.startBroadcast(pk);
        CrownZkAutoDraw autoDraw = new CrownZkAutoDraw(CREDIT, USDC);
        IZkCreditOp(CREDIT).setOperator(address(autoDraw), true);
        vm.stopBroadcast();

        require(IZkCreditOp(CREDIT).operator(address(autoDraw)), "OP");
        (uint256 maxB, bool proven, uint256 bal) = autoDraw.quote();
        console2.log("AUTO_DRAW", address(autoDraw));
        console2.log("operatorSet", uint256(1));
        console2.log("proven", proven ? uint256(1) : uint256(0));
        console2.log("maxBorrow", maxB);
        console2.log("creditUsdc", bal);
        console2.log("ZK_AUTO_DEPLOY_OK", uint256(1));
    }
}

interface IZkCreditOp {
    function setOperator(address, bool) external;
    function operator(address) external view returns (bool);
}
