// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkLoanComplete} from "../src/CrownZkLoanComplete.sol";

interface IZkCreditOp {
    function setOperator(address, bool) external;
    function operator(address) external view returns (bool);
}

/// @notice Deploy atomic loan completer + set as credit operator.
/// @dev KING_GO=1 FIRE_LOAN_COMPLETE=1
contract FireDeployLoanComplete is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_LOAN_COMPLETE", uint256(0)) == 1, "NEED FIRE_LOAN_COMPLETE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        vm.startBroadcast(pk);
        CrownZkLoanComplete c = new CrownZkLoanComplete(CREDIT, USDC);
        IZkCreditOp(CREDIT).setOperator(address(c), true);
        vm.stopBroadcast();

        require(IZkCreditOp(CREDIT).operator(address(c)), "OP");
        console2.log("LOAN_COMPLETE", address(c));
        console2.log("maxAsk", c.maxAsk());
        console2.log("LOAN_COMPLETE_DEPLOY_OK", uint256(1));
    }
}
