// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IOneDrop {
    function execute(uint256 rssAmount, uint256 kusdAmount, uint256 usdcOutMin, uint256 morphoPost) external;
}

interface IERC20E {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Execute one-drop. KING_OK=1 KING_GO=1 FIRE_ONEDROP=1
/// @dev Aero kUSD/USDC depth is thin — large swaps will fail or return dust until pool deepened.
contract FireOneDropExecute is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_KING_GO");
        require(vm.envOr("FIRE_ONEDROP", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address oneDrop = vm.envAddress("ONEDROP");
        uint256 rssAmt = vm.envUint("RSS_AMT");
        uint256 kusdAmt = vm.envUint("KUSD_AMT");
        uint256 usdcMin = vm.envOr("USDC_MIN", uint256(0));
        uint256 morphoPost = vm.envOr("MORPHO_POST", uint256(0));

        uint256 landBefore = IERC20E(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        IERC20E(RSS).approve(oneDrop, rssAmt + morphoPost);
        IOneDrop(oneDrop).execute(rssAmt, kusdAmt, usdcMin, morphoPost);
        vm.stopBroadcast();

        uint256 landAfter = IERC20E(USDC).balanceOf(LANDING);
        console2.log("usdcToLanding", landAfter - landBefore);
        console2.log("ONEDROP_OK", uint256(1));
    }
}
