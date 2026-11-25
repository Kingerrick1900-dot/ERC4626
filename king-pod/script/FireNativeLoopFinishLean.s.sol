// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownExitNative} from "../src/CrownExitNative.sol";
import {CrownEusdSleeve} from "../src/CrownEusdSleeve.sol";

interface ICold {
    function armOutflow(bool armed) external;
    function setRedemptionSink(address sink) external;
    function releaseToSink(uint256 amount, bytes32 reason) external;
    function balance() external view returns (uint256);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Lean finish — no new deploys. Cold→Exit inventory→eUSD exit→HOT USDC scoreboard.
contract FireNativeLoopFinishLean is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    address constant AAVE_EUSD_SLEEVE = 0x3c55Ef84eE345e05B60039512daEd331a4d5C441;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        uint256 coldBal = ICold(COLD).balance();
        require(coldBal > 0, "NO_COLD");
        uint256 eusdNeed = coldBal * 1e12;

        vm.startBroadcast(pk);
        ICold(COLD).armOutflow(true);
        ICold(COLD).setRedemptionSink(EXIT);
        ICold(COLD).releaseToSink(coldBal, keccak256("EXIT-SEED"));
        CrownEusdSleeve(AAVE_EUSD_SLEEVE).pull(HOT, eusdNeed);
        IERC20b(EUSD).approve(EXIT, eusdNeed);
        bytes32 nfc = keccak256(abi.encode("NFC-EXIT-LEAN", coldBal, block.timestamp));
        uint256 out = CrownExitNative(EXIT).exit(eusdNeed, USDC, coldBal, nfc);
        vm.stopBroadcast();

        console2.log("exitedUsdc", out);
        console2.log("hotUsdc", IERC20b(USDC).balanceOf(HOT));
        console2.log("exitEusd", IERC20b(EUSD).balanceOf(EXIT));
    }
}
