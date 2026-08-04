// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBoundPermit2Completer} from "../src/CrownBoundPermit2Completer.sol";

interface ICreditOps {
    function setOperator(address op, bool allowed) external;
    function operator(address) external view returns (bool);
    function owner() external view returns (address);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
}

interface IGateF {
    function isProven(address) external view returns (bool);
}

interface IOldCompleter {
    function maxAsk() external view returns (uint256);
}

/// @notice Deploy Permit2 Completer, setOperator, status. FIRE=1 to broadcast.
/// @dev MODE=deploy|status  ROUTER=existing optional
contract FirePermit2Completer is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CREDIT = 0x20B1513a137b9CB166E2cC15c405e842278E7D1A;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant OLD_COMPLETER = 0x3827dA0c33891ee058847BB896D6287C5814F7C6;

    function run() external {
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        address existing = vm.envOr("P2_COMPLETER", address(0));

        console2.log("=== PERMIT2 COMPLETER (TRACK A) ===");
        console2.log("proven", IGateF(GATE).isProven(HOT) ? 1 : 0);
        console2.log("credit USDC", IERC20F(USDC).balanceOf(CREDIT));
        console2.log("hot USDC", IERC20F(USDC).balanceOf(HOT));
        console2.log("Landing USDC", IERC20F(USDC).balanceOf(LANDING));
        console2.log("old maxAsk", IOldCompleter(OLD_COMPLETER).maxAsk());
        console2.log("credit owner", ICreditOps(CREDIT).owner());

        if (!fire) {
            console2.log("DRY - set FIRE=1 to deploy + setOperator");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(ICreditOps(CREDIT).owner() == HOT, "NOT_CREDIT_OWNER");

        vm.startBroadcast(pk);
        CrownBoundPermit2Completer c;
        if (existing == address(0)) {
            c = new CrownBoundPermit2Completer(CREDIT, USDC, PERMIT2);
            console2.log("DEPLOYED", address(c));
        } else {
            c = CrownBoundPermit2Completer(existing);
            console2.log("USING", address(c));
        }
        if (!ICreditOps(CREDIT).operator(address(c))) {
            ICreditOps(CREDIT).setOperator(address(c), true);
            console2.log("OPERATOR_SET", uint256(1));
        }
        vm.stopBroadcast();

        console2.log("operator", ICreditOps(CREDIT).operator(address(c)) ? 1 : 0);
        console2.log("maxAsk", c.maxAsk());
        console2.log("PERMIT2_COMPLETER_OK");
    }
}
