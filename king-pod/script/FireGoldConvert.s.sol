// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldConvert} from "../src/CrownGoldConvert.sol";

interface IERC20B {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire Route B. Env:
///   CONVERT=, MODE=twamm|ask|uni
///   TOKEN=, AMOUNT_IN=, MIN_USDC_PER= (twamm), MIN_OUT= (ask/uni),
///   WINDOW= (twamm seconds, default 604800), FEE= (uni, default 3000)
/// Requires FIRE_3M=1 to broadcast posts that escrow inventory.
contract FireGoldConvert is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant KXAU = 0x76822B470DeC1b94Df4219727288e7a196224853;

    function run() external {
        require(vm.envOr("FIRE_3M", uint256(0)) == 1, "FIRE_3M");

        address convertAddr = vm.envAddress("CONVERT");
        string memory mode = vm.envOr("MODE", string("twamm"));
        address token = vm.envOr("TOKEN", KXAU);
        uint256 amountIn = vm.envUint("AMOUNT_IN");

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownGoldConvert convert = CrownGoldConvert(convertAddr);

        vm.startBroadcast(pk);

        IERC20B(token).approve(convertAddr, amountIn);

        if (keccak256(bytes(mode)) == keccak256("twamm")) {
            uint256 minPer = vm.envOr("MIN_USDC_PER", uint256(9_800_000)); // $9.80
            uint64 window = uint64(vm.envOr("WINDOW", uint256(604800)));
            uint64 start = uint64(block.timestamp);
            uint64 end = start + window;
            uint256 id = convert.postTwamm(token, amountIn, minPer, start, end);
            console2.log("twammId", id);
            console2.log("minUsdcPerFull", minPer);
            console2.log("end", end);
        } else if (keccak256(bytes(mode)) == keccak256("ask")) {
            uint256 minOut = vm.envUint("MIN_OUT");
            uint64 deadline = uint64(block.timestamp + vm.envOr("WINDOW", uint256(604800)));
            uint256 id = convert.postAsk(token, amountIn, minOut, deadline);
            console2.log("askId", id);
            console2.log("minOut", minOut);
        } else if (keccak256(bytes(mode)) == keccak256("uni")) {
            uint256 minOut = vm.envUint("MIN_OUT");
            uint24 fee = uint24(vm.envOr("FEE", uint256(3000)));
            uint256 out = convert.uniSell(token, amountIn, minOut, fee);
            console2.log("uniOut", out);
        } else {
            revert("MODE");
        }

        (uint256 target, uint256 filled,,,) = convert.book();
        console2.log("targetUsdc", target);
        console2.log("filledUsdc", filled);

        vm.stopBroadcast();
        console2.log("MISSION Route B convert armed");
    }
}
