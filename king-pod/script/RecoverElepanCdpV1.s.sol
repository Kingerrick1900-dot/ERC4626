// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20R {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ICdpR {
    function repay(uint256) external;
    function withdraw(uint256) external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function maxWithdrawable() external view returns (uint256);
}

interface IEusdR {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Recover Elepan from CDP v1 (fee shortfall blocks close). Repay bal + withdraw max.
contract RecoverElepanCdpV1 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0x3a8Cf4f9B8AEEE608840978462F59853f359F47A;
    address constant CDP_V1 = 0xB333ABbC070128bFC916FDf024a8942BDEa534f3;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 bal = IEusdR(EUSD).balanceOf(HOT);
        uint256 collBefore = ICdpR(CDP_V1).coll();
        console2.log("eusdBal", bal);
        console2.log("collBefore", collBefore);
        console2.log("debtBefore", ICdpR(CDP_V1).accruedDebt());

        vm.startBroadcast(pk);
        if (bal > 0) ICdpR(CDP_V1).repay(bal);
        uint256 w = ICdpR(CDP_V1).maxWithdrawable();
        // Extra buffer: V1 maxWithdrawable can be 1 unit optimistic vs HF check.
        if (w > 10) w -= 10;
        console2.log("withdrawMax", w);
        if (w > 0) ICdpR(CDP_V1).withdraw(w);
        vm.stopBroadcast();

        console2.log("collAfter", ICdpR(CDP_V1).coll());
        console2.log("debtAfter", ICdpR(CDP_V1).accruedDebt());
        console2.log("elepanHot", IERC20R(ELEPAN).balanceOf(HOT));
        console2.log("V1_RECOVER_OK", uint256(1));
    }
}
