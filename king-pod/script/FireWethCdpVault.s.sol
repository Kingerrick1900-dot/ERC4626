// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoUniV3Oracle} from "../src/MorphoUniV3Oracle.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownWethCdpVault} from "../src/CrownWethCdpVault.sol";

interface IZkGateV {
    function isProven(address) external view returns (bool);
}

/// @notice Deploy WETH CDP + MorphoUniV3Oracle on live WETH/USDC TWAP pool (same as Elepan loan ora).
/// @dev Also deploys multi-minter eUSD if EUSD env unset. KING_GO=1 FIRE_WETH_CDP=1.
contract FireWethCdpVault is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH_USDC_POOL = 0xd0b53D9277642d899DF5C87A3966A349A798F224; // live TWAP source
    uint32 constant TWAP = 1800;

    // Market-priced: LR 130% / floor 135% / fee 5%
    uint256 constant LR = 1.3e18;
    uint256 constant FLOOR = 1.35e18;
    uint256 constant FEE_BPS = 500;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_WETH_CDP", uint256(0)) == 1, "NEED FIRE_WETH_CDP=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateV(ZK_GATE).isProven(HOT), "HOT_NOT_ZK_PROVEN");

        address eusdAddr = vm.envOr("EUSD", address(0));

        vm.startBroadcast(pk);
        if (eusdAddr == address(0)) {
            CrownElepanUsd e = new CrownElepanUsd(HOT);
            eusdAddr = address(e);
            console2.log("eUSD_new", eusdAddr);
        }
        MorphoUniV3Oracle ora = new MorphoUniV3Oracle(WETH_USDC_POOL, WETH, USDC, TWAP, 18, 6);
        CrownWethCdpVault vault = new CrownWethCdpVault(
            eusdAddr, address(ora), ZK_GATE, HOT, HOT, LR, FLOOR, FEE_BPS
        );
        CrownElepanUsd(eusdAddr).setMinter(address(vault), true);
        vm.stopBroadcast();

        console2.log("oracle", address(ora));
        console2.log("oraclePrice", ora.price());
        console2.log("WethCdp", address(vault));
        console2.log("eUSD", eusdAddr);
        console2.log("WETH_CDP_DEPLOYED", uint256(1));
    }
}
