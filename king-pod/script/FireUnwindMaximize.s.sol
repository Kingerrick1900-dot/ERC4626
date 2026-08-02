// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ICdpU {
    function repay(uint256 repayAmt) external;
    function withdraw(uint256 collAmt) external;
    function collOf(address) external view returns (uint256);
    function debtOf(address) external view returns (uint256);
}

interface IAdvU {
    function unstockKusd(uint256 amt, address to) external;
    function kusdStock() external view returns (uint256);
}

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice UNWIND unauthorized maximize: pull kUSD from Advance, repay CDP, withdraw RSS.
/// @dev KING_OK=1 FIRE_UNWIND_MAX=1
contract FireUnwindMaximize is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant KUSD = 0x0FEA62084A024544891f03035E85401C2C886c1b;
    address constant CDP = 0x9F9356dd8B17f58d03f3Db84e81541cdABBD5768;
    address constant ADV = 0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;

    // Exact amounts from unauthorized maximize fire
    uint256 constant UNWIND_KUSD = 2_800_000e6;
    uint256 constant UNWIND_RSS = 4_000_000 ether;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_UNWIND_MAX", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 debt = ICdpU(CDP).debtOf(HOT);
        uint256 coll = ICdpU(CDP).collOf(HOT);
        uint256 adv = IAdvU(ADV).kusdStock();
        require(debt >= UNWIND_KUSD, "DEBT");
        require(coll >= UNWIND_RSS, "COLL");
        require(adv >= UNWIND_KUSD, "ADV");

        vm.startBroadcast(pk);
        IAdvU(ADV).unstockKusd(UNWIND_KUSD, HOT);
        ICdpU(CDP).repay(UNWIND_KUSD);
        ICdpU(CDP).withdraw(UNWIND_RSS);
        vm.stopBroadcast();

        console2.log("collNow", ICdpU(CDP).collOf(HOT));
        console2.log("debtNow", ICdpU(CDP).debtOf(HOT));
        console2.log("advNow", IAdvU(ADV).kusdStock());
        console2.log("rssHot", IERC20U(RSS).balanceOf(HOT));
        console2.log("UNWIND_OK", uint256(1));
    }
}
