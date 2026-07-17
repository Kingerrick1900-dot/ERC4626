// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KingSusdc} from "../src/KingSusdc.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingOracle} from "../src/KingOracle.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";
import {KingPodAave} from "../src/KingPodAave.sol";

/// @dev New Option-A stack for liquid-RSS scale (do not reuse v1 pair ratio).
contract DeployAavePod is Script {
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        KingSusdc sUsdc = new KingSusdc(USDC, KING);
        KingPair pair = new KingPair(RSS, address(sUsdc), KING);
        KingOracle oracle = new KingOracle(RSS, address(sUsdc), address(pair), KING);
        KingMoneyMarket market = new KingMoneyMarket(USDC, address(sUsdc), address(pair), address(oracle), KING);
        KingPodAave pod = new KingPodAave(
            RSS, USDC, address(sUsdc), address(pair), address(market), AAVE_POOL, KING, KING
        );

        // Wire: market pulls sUSDC assets; pod is operator for credit/borrowTo
        sUsdc.transferOwnership(address(market));
        market.setOperator(address(pod));

        console2.log("sUsdc", address(sUsdc));
        console2.log("pair", address(pair));
        console2.log("oracle", address(oracle));
        console2.log("market", address(market));
        console2.log("podAave", address(pod));

        vm.stopBroadcast();
    }
}
