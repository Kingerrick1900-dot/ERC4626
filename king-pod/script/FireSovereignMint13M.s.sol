// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ICdpM {
    function deposit(uint256) external;
    function mintTo(address, uint256) external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
    function treasury() external view returns (address);
    function eusd() external view returns (address);
}

interface IEusdM {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Phase-1B: lock Elepan, mint $13M eUSD → Landing (Access Clause).
/// @dev KING_GO=1 FIRE_MINT_13M=1 ELEPAN_CDP=0x... — no broadcast without flags.
contract FireSovereignMint13M is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;

    uint256 constant MINT = 13_000_000 ether;
    // Soft $1 · floor 155% → ≥20.15M Elepan + buffer
    uint256 constant COLL = 20_200_000e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MINT_13M", uint256(0)) == 1, "NEED FIRE_MINT_13M=1");
        address cdp = vm.envAddress("ELEPAN_CDP");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(ICdpM(cdp).treasury() == LANDING, "TREASURY_NOT_LANDING");
        require(IERC20M(ELEPAN).balanceOf(HOT) >= COLL, "ELEPAN_BAL");

        address eusd = ICdpM(cdp).eusd();
        uint256 landingBefore = IEusdM(eusd).balanceOf(LANDING);

        vm.startBroadcast(pk);
        IERC20M(ELEPAN).approve(cdp, COLL);
        ICdpM(cdp).deposit(COLL);
        ICdpM(cdp).mintTo(LANDING, MINT);
        vm.stopBroadcast();

        uint256 landingAfter = IEusdM(eusd).balanceOf(LANDING);
        require(landingAfter >= landingBefore + MINT, "ACCESS_CLAUSE_FAIL");
        require(ICdpM(cdp).accruedDebt() >= MINT, "DEBT");
        require(ICdpM(cdp).healthFactor() >= ICdpM(cdp).safetyFloor(), "HF");
        require(IEusdM(eusd).balanceOf(cdp) == 0, "VAULT_MUST_NOT_HOLD_EUSD");

        console2.log("coll", ICdpM(cdp).coll());
        console2.log("debt", ICdpM(cdp).accruedDebt());
        console2.log("hf", ICdpM(cdp).healthFactor());
        console2.log("landingEusd", landingAfter);
        console2.log("MINT_13M_TO_LANDING_OK", uint256(1));
    }
}
