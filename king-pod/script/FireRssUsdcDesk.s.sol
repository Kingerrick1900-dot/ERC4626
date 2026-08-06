// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssUsdcDesk} from "../src/CrownRssUsdcDesk.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Track 1 live: DESK must already be funded with USDC by lender.
/// Env: PRIVATE_KEY, DESK, RSS_IN, USDC_OUT (default 700_000e6)
contract FireRssUsdcDesk is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        address desk = vm.envAddress("DESK");
        uint256 rssIn = vm.envOr("RSS_IN", uint256(1000e18));
        uint256 usdcOut = vm.envOr("USDC_OUT", uint256(700_000e6));

        vm.startBroadcast(pk);
        IERC20S(RSS).approve(desk, rssIn);
        CrownRssUsdcDesk(desk).draw(rssIn, usdcOut, LANDING);
        vm.stopBroadcast();

        console2.log("LANDING_USDC", IERC20S(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913).balanceOf(LANDING));
    }
}
