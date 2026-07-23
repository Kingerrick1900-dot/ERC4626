// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20Z {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ICdpZ {
    function deposit(uint256) external;
    function mint(uint256) external;
    function withdraw(uint256) external;
    function close() external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
    function zkGate() external view returns (address);
}

interface IGateZ {
    function isProven(address) external view returns (bool);
}

interface IEusdZ {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Live smoke on ZK-gated CDP: deposit → mint → partial withdraw → close.
contract SmokeElepanCdpZk is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0x2b87771181d5d59B8e0C4fEEc055bbBE0C447B99;
    address constant CDP = 0x3b07C86a4058B160C84aF860100bE5FfDD0685eB;
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;

    uint256 constant COLL = 10e8;
    uint256 constant MINT = 5 ether;
    uint256 constant PARTIAL = 1e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CDP_SMOKE", uint256(0)) == 1, "NEED FIRE_CDP_SMOKE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(ICdpZ(CDP).zkGate() == ZK_GATE, "GATE");
        require(IGateZ(ZK_GATE).isProven(HOT), "NOT_PROVEN");

        vm.startBroadcast(pk);
        IERC20Z(ELEPAN).approve(CDP, COLL);
        ICdpZ(CDP).deposit(COLL);
        ICdpZ(CDP).mint(MINT);
        uint256 hfMint = ICdpZ(CDP).healthFactor();
        console2.log("hfAfterMint", hfMint);
        require(hfMint >= ICdpZ(CDP).safetyFloor(), "HF_MINT");

        ICdpZ(CDP).withdraw(PARTIAL);
        uint256 hfPartial = ICdpZ(CDP).healthFactor();
        console2.log("hfAfterPartial", hfPartial);
        require(hfPartial >= ICdpZ(CDP).safetyFloor(), "HF_PARTIAL");
        require(ICdpZ(CDP).coll() == COLL - PARTIAL, "COLL");

        IEusdZ(EUSD).approve(CDP, type(uint256).max);
        ICdpZ(CDP).close();
        vm.stopBroadcast();

        require(ICdpZ(CDP).coll() == 0 && ICdpZ(CDP).accruedDebt() == 0, "NOT_CLOSED");
        console2.log("ZK_CDP_PARTIAL_WITHDRAW_LIVE_OK", uint256(1));
    }
}
