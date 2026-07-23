// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ICdpC {
    function withdraw(uint256) external;
    function close() external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
    function maxWithdrawable() external view returns (uint256);
}

interface IEusdC {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Continue smoke after OOG on withdraw: partial withdraw + close.
contract SmokeElepanCdpContinue is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xaeDcB6cCEc9739A3a2e4c4d3F914BC676a906E55;
    address constant CDP = 0xD0108e7570dB003D8140949d2b68Dd3e3F81ED14;
    uint256 constant PARTIAL = 1e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        console2.log("coll", ICdpC(CDP).coll());
        console2.log("debt", ICdpC(CDP).accruedDebt());
        console2.log("maxW", ICdpC(CDP).maxWithdrawable());

        vm.startBroadcast(pk);
        ICdpC(CDP).withdraw(PARTIAL);
        uint256 hf = ICdpC(CDP).healthFactor();
        console2.log("hfAfterPartial", hf);
        require(hf >= ICdpC(CDP).safetyFloor(), "HF");
        require(ICdpC(CDP).coll() == 9e8, "COLL");

        IEusdC(EUSD).approve(CDP, type(uint256).max);
        ICdpC(CDP).close();
        vm.stopBroadcast();

        require(ICdpC(CDP).coll() == 0, "COLL_LEFT");
        require(ICdpC(CDP).accruedDebt() == 0, "DEBT_LEFT");
        require(IEusdC(EUSD).balanceOf(HOT) == 0, "EUSD_LEFT");
        console2.log("PARTIAL_WITHDRAW_LIVE_OK", uint256(1));
    }
}
