// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUnlockRss} from "../src/CrownUnlockRss.sol";

interface IMorphoA {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice UNLOCK — one-tx repay + free all RSS to hot. Stop waiting on empty pool.
/// @dev KING_OK=1 KING_GO=1 FIRE_UNLOCK=1
contract FireUnlockRss is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant RSS91 = 0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        require(vm.envOr("FIRE_UNLOCK", uint256(0)) == 1, "FIRE_UNLOCK");

        console2.log("rssBefore", IERC20A(RSS).balanceOf(HOT));
        console2.log("usdcBefore", IERC20A(USDC).balanceOf(HOT));

        vm.startBroadcast(pk);
        CrownUnlockRss u = new CrownUnlockRss(MORPHO, USDC, RSS, HOT, RSS77, RSS91);
        IMorphoA(MORPHO).setAuthorization(address(u), true);
        IERC20A(USDC).approve(address(u), type(uint256).max);
        u.unlock();
        vm.stopBroadcast();

        (, uint128 b77, uint128 c77) = IMorphoA(MORPHO).position(RSS77, HOT);
        (, uint128 b91, uint128 c91) = IMorphoA(MORPHO).position(RSS91, HOT);
        console2.log("rssAfter", IERC20A(RSS).balanceOf(HOT));
        console2.log("usdcAfter", IERC20A(USDC).balanceOf(HOT));
        console2.log("bor77", uint256(b77));
        console2.log("coll77", uint256(c77));
        console2.log("bor91", uint256(b91));
        console2.log("coll91", uint256(c91));
        require(b77 == 0 && c77 == 0 && b91 == 0 && c91 == 0, "NOT CLEAR");
        console2.log("UNLOCK_OK", uint256(1));
    }
}
