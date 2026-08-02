// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoUniV3Oracle} from "../src/MorphoUniV3Oracle.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownCbbtcCdpVault} from "../src/CrownCbbtcCdpVault.sol";

interface IZkGateC {
    function isProven(address) external view returns (bool);
}

/// @notice Deploy cbBTC CDP + MorphoUniV3Oracle on live cbBTC/USDC TWAP pool.
/// @dev Requires EUSD=. ACCESS CLAUSE: treasury=Landing. KING_GO=1 FIRE_CBBTC_CDP=1.
contract FireCbbtcCdpVault is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBTC_USDC_POOL = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;
    uint32 constant TWAP = 1800;

    uint256 constant LR = 1.3e18;
    uint256 constant FLOOR = 1.35e18;
    uint256 constant FEE_BPS = 500;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CBBTC_CDP", uint256(0)) == 1, "NEED FIRE_CBBTC_CDP=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateC(ZK_GATE).isProven(HOT), "HOT_NOT_ZK_PROVEN");

        address eusdAddr = vm.envAddress("EUSD");
        require(eusdAddr != address(0), "EUSD");

        vm.startBroadcast(pk);
        MorphoUniV3Oracle ora = new MorphoUniV3Oracle(CBTC_USDC_POOL, CBTC, USDC, TWAP, 8, 6);
        CrownCbbtcCdpVault vault = new CrownCbbtcCdpVault(
            eusdAddr, address(ora), ZK_GATE, HOT, LANDING, LANDING, LR, FLOOR, FEE_BPS
        );
        CrownElepanUsd(eusdAddr).setMinter(address(vault), true);
        vm.stopBroadcast();

        console2.log("oracle", address(ora));
        console2.log("CbbtcCdp", address(vault));
        console2.log("treasury", vault.treasury());
        console2.log("eUSD", eusdAddr);
        console2.log("CBBTC_CDP_DEPLOYED", uint256(1));
    }
}
