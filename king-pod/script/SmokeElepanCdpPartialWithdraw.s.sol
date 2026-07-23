// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ICdp {
    function deposit(uint256) external;
    function mint(uint256) external;
    function withdraw(uint256) external;
    function repay(uint256) external;
    function close() external;
    function coll() external view returns (uint256);
    function debt() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function maxWithdrawable() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
}

interface IEusd {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Live smoke: deposit → mint → partial withdraw (HF ≥ floor) → close.
contract SmokeElepanCdpPartialWithdraw is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0xaeDcB6cCEc9739A3a2e4c4d3F914BC676a906E55;
    address constant CDP = 0xD0108e7570dB003D8140949d2b68Dd3e3F81ED14;

    // 10 Elepan (~$10 soft) → mint 5 eUSD → withdraw 1 Elepan partial → close
    uint256 constant COLL = 10e8;
    uint256 constant MINT = 5 ether;
    uint256 constant PARTIAL = 1e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CDP_SMOKE", uint256(0)) == 1, "NEED FIRE_CDP_SMOKE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        console2.log("elepanBefore", IERC20S(ELEPAN).balanceOf(HOT));
        console2.log("floor", ICdp(CDP).safetyFloor());

        vm.startBroadcast(pk);
        IERC20S(ELEPAN).approve(CDP, COLL);
        ICdp(CDP).deposit(COLL);
        ICdp(CDP).mint(MINT);
        uint256 hfAfterMint = ICdp(CDP).healthFactor();
        console2.log("hfAfterMint", hfAfterMint);
        require(hfAfterMint >= ICdp(CDP).safetyFloor(), "HF_MINT");

        uint256 maxW = ICdp(CDP).maxWithdrawable();
        console2.log("maxWithdrawable", maxW);
        require(maxW >= PARTIAL, "NO_PARTIAL_ROOM");
        ICdp(CDP).withdraw(PARTIAL);
        uint256 hfAfterPartial = ICdp(CDP).healthFactor();
        console2.log("hfAfterPartial", hfAfterPartial);
        require(hfAfterPartial >= ICdp(CDP).safetyFloor(), "HF_PARTIAL");
        require(ICdp(CDP).coll() == COLL - PARTIAL, "COLL");

        // Full exit
        IEusd(EUSD).approve(CDP, type(uint256).max);
        ICdp(CDP).close();
        vm.stopBroadcast();

        require(ICdp(CDP).coll() == 0, "COLL_LEFT");
        require(ICdp(CDP).accruedDebt() == 0, "DEBT_LEFT");
        console2.log("PARTIAL_WITHDRAW_LIVE_OK", uint256(1));
    }
}
