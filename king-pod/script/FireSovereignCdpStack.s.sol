// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoUniV3Oracle} from "../src/MorphoUniV3Oracle.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownElepanCdpVault} from "../src/CrownElepanCdpVault.sol";
import {CrownWethCdpVault} from "../src/CrownWethCdpVault.sol";
import {CrownCbbtcCdpVault} from "../src/CrownCbbtcCdpVault.sol";

interface IZkG {
    function isProven(address) external view returns (bool);
}

/// @notice Phase-1A deploy: unified multi-minter eUSD + 3 CDPs (treasury=Landing).
/// @dev NO broadcast without KING_GO=1 FIRE_SOVEREIGN_CDP=1. Does NOT mint $13M (Phase 1B).
contract FireSovereignCdpStack is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_ELEPAN = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH_USDC_POOL = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address constant CBTC_USDC_POOL = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;

    uint256 constant LR_E = 1.5e18;
    uint256 constant FLOOR_E = 1.55e18;
    uint256 constant LR_M = 1.3e18;
    uint256 constant FLOOR_M = 1.35e18;
    uint256 constant FEE_BPS = 500;
    uint32 constant TWAP = 1800;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SOVEREIGN_CDP", uint256(0)) == 1, "NEED FIRE_SOVEREIGN_CDP=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkG(ZK_GATE).isProven(HOT), "HOT_NOT_ZK_PROVEN");

        vm.startBroadcast(pk);
        CrownElepanUsd eusd = new CrownElepanUsd(HOT);

        CrownElepanCdpVault elepanVault = new CrownElepanCdpVault(
            ELEPAN, address(eusd), ORACLE_ELEPAN, ZK_GATE, HOT, LANDING, LANDING, LR_E, FLOOR_E, FEE_BPS
        );
        MorphoUniV3Oracle oraW = new MorphoUniV3Oracle(WETH_USDC_POOL, WETH, USDC, TWAP, 18, 6);
        CrownWethCdpVault wethVault = new CrownWethCdpVault(
            address(eusd), address(oraW), ZK_GATE, HOT, LANDING, LANDING, LR_M, FLOOR_M, FEE_BPS
        );
        MorphoUniV3Oracle oraB = new MorphoUniV3Oracle(CBTC_USDC_POOL, CBTC, USDC, TWAP, 8, 6);
        CrownCbbtcCdpVault cbbtcVault = new CrownCbbtcCdpVault(
            address(eusd), address(oraB), ZK_GATE, HOT, LANDING, LANDING, LR_M, FLOOR_M, FEE_BPS
        );

        eusd.setMinter(address(elepanVault), true);
        eusd.setMinter(address(wethVault), true);
        eusd.setMinter(address(cbbtcVault), true);
        vm.stopBroadcast();

        console2.log("eUSD", address(eusd));
        console2.log("ElepanCDP", address(elepanVault));
        console2.log("WethCDP", address(wethVault));
        console2.log("CbbtcCDP", address(cbbtcVault));
        console2.log("WethOracle", address(oraW));
        console2.log("CbbtcOracle", address(oraB));
        require(elepanVault.treasury() == LANDING, "TREASURY");
        console2.log("SOVEREIGN_CDP_STACK_DEPLOYED", uint256(1));
    }
}
