// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";

interface IZkShieldGate {
    function isProven(address subject) external view returns (bool);
}

interface IZkBorders {
    function bordersSecure() external view returns (bool);
}

/// @notice Kingdom fire law: ZK_SHIELD=1 · bordersSecure · WalletGate isProven(subject).
library ZkShieldLaw {
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;

    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function requireFire(address subject) internal view {
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD");
        require(IZkBorders(BASE_ATTEST).bordersSecure(), "BORDERS");
        require(IZkShieldGate(ZK_WALLET_GATE).isProven(subject), "NOT_PROVEN_SUBJECT");
        require(IZkShieldGate(ZK_WALLET_GATE).isProven(SAFE), "NOT_PROVEN_SAFE");
    }
}
