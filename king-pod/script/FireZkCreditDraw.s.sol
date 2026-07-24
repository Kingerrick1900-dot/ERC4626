// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20Z {
    function balanceOf(address) external view returns (uint256);
}

interface IZkGateZ {
    function isProven(address) external view returns (bool);
}

interface IZkCreditZ {
    function maxBorrow(address) external view returns (uint256);
    function borrow(uint256 amount) external;
    function landing() external view returns (address);
    function lltv() external view returns (uint256);
}

/// @notice Draw USDC from ZK credit → Landing after counterparty supply.
/// @dev KING_GO=1 FIRE_ZK_CREDIT=1 ASK_USDC=<raw6>
contract FireZkCreditDraw is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ZK_CREDIT", uint256(0)) == 1, "NEED FIRE_ZK_CREDIT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateZ(GATE).isProven(HOT), "NOT_PROVEN");
        require(IZkCreditZ(CREDIT).landing() == LANDING, "LANDING");

        uint256 ask = vm.envUint("ASK_USDC");
        uint256 maxB = IZkCreditZ(CREDIT).maxBorrow(HOT);
        require(maxB > 0, "POOL_EMPTY");
        require(ask > 0 && ask <= maxB, "ASK_SIZE");

        uint256 before = IERC20Z(USDC).balanceOf(LANDING);
        vm.startBroadcast(pk);
        IZkCreditZ(CREDIT).borrow(ask);
        vm.stopBroadcast();

        console2.log("asked", ask);
        console2.log("maxBorrow", maxB);
        console2.log("landingUsdc", IERC20Z(USDC).balanceOf(LANDING));
        console2.log("ZK_DRAW_OK", IERC20Z(USDC).balanceOf(LANDING) >= before + ask ? uint256(1) : uint256(0));
    }
}
