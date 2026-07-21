// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Loop ops wallet funds Hot (Morpho signer) with USDC and/or ETH for gas/seeds.
/// @dev OPS = loop `0x8d3cfbFc6A276f118579517E4d166e94C66F8585` ONLY. LOOP_PRIVATE_KEY required.
///      KING_OK=1 KING_GO=1 FIRE_FUND=1
contract FireLoopFundHot is Script {
    address constant OPS_LOOP = 0x8d3cfbFc6A276f118579517E4d166e94C66F8585;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        require(vm.envOr("FIRE_FUND", uint256(0)) == 1, "FIRE_FUND");

        uint256 loopPk = vm.envUint("LOOP_PRIVATE_KEY");
        require(vm.addr(loopPk) == OPS_LOOP, "OPS_MUST_BE_LOOP");

        uint256 loopUsdcFloor = vm.envOr("LOOP_USDC_FLOOR", uint256(1_000_000)); // keep $1 on loop
        uint256 hotUsdcTarget = vm.envOr("HOT_USDC_TARGET", uint256(10_000_000)); // $10 hot ops float
        uint256 fundUsdcCap = vm.envOr("FUND_USDC", uint256(0)); // 0 = fill hot to target
        uint256 fundEth = vm.envOr("FUND_ETH", uint256(0)); // wei; 0 = skip ETH
        uint256 loopGasReserve = vm.envOr("LOOP_GAS_RESERVE", uint256(0.0002 ether));

        uint256 loopUsdc = IERC20L(USDC).balanceOf(OPS_LOOP);
        uint256 hotUsdcBefore = IERC20L(USDC).balanceOf(HOT);
        uint256 hotEthBefore = HOT.balance;

        console2.log("=== LOOP FUND HOT ===");
        console2.log("loopUsdc", loopUsdc);
        console2.log("hotUsdcBefore", hotUsdcBefore);
        console2.log("hotEthBefore", hotEthBefore);

        uint256 sendUsdc;
        if (hotUsdcBefore < hotUsdcTarget && loopUsdc > loopUsdcFloor) {
            sendUsdc = hotUsdcTarget - hotUsdcBefore;
            if (fundUsdcCap > 0 && sendUsdc > fundUsdcCap) sendUsdc = fundUsdcCap;
            uint256 loopAvail = loopUsdc - loopUsdcFloor;
            if (sendUsdc > loopAvail) sendUsdc = loopAvail;
        }

        uint256 sendEth;
        if (fundEth > 0) {
            sendEth = fundEth;
            uint256 loopEthAvail = OPS_LOOP.balance;
            if (loopEthAvail > sendEth + loopGasReserve) {
                // ok
            } else if (loopEthAvail > loopGasReserve) {
                sendEth = loopEthAvail - loopGasReserve;
            } else {
                sendEth = 0;
            }
        }

        require(sendUsdc > 0 || sendEth > 0, "LOOP_EMPTY: fund loop wallet first");

        vm.startBroadcast(loopPk);
        if (sendUsdc > 0) {
            require(IERC20L(USDC).transfer(HOT, sendUsdc), "USDC");
        }
        if (sendEth > 0) {
            (bool ok,) = HOT.call{value: sendEth}("");
            require(ok, "ETH");
        }
        vm.stopBroadcast();

        console2.log("sentUsdc", sendUsdc);
        console2.log("sentEth", sendEth);
        console2.log("hotUsdcAfter", IERC20L(USDC).balanceOf(HOT));
        console2.log("hotEthAfter", HOT.balance);
        console2.log("FUND_OK", uint256(1));
    }
}
