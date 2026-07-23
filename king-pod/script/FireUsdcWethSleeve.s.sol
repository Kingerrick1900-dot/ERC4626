// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUsdcWethSleeve} from "../src/CrownUsdcWethSleeve.sol";
import {CrownFhePrivateVaultV2} from "../src/CrownFhePrivateVaultV2.sol";

interface IMMA {
    function setIsAllocator(address, bool) external;
    function isAllocator(address) external view returns (bool);
}

interface IV2A {
    function submit(bytes memory) external;
    function setIsAllocator(address, bool) external;
    function isAllocator(address) external view returns (bool);
}

/// @notice Deploy USDC→WETH sleeve + FHE vault v2; grant allocator on MM + V2.
/// @dev KING_GO=1 FIRE_SLEEVE=1
contract FireUsdcWethSleeve is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481; // SwapRouter02 Base
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant Y_MM = 0xfdD5a1d4823411809D6ac735991B3A015E5AaAb5;
    address constant Y_V2 = 0x35a00F116536c13A63273513990E4E496a15Ddb2;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SLEEVE", uint256(0)) == 1, "NEED FIRE_SLEEVE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        vm.startBroadcast(pk);

        CrownFhePrivateVaultV2 fhe = new CrownFhePrivateVaultV2(USDC, GATE, HOT, HOT);
        // optional management fee 0; perf 10% already default
        fhe.setFees(1000, 0);

        CrownUsdcWethSleeve sleeve =
            new CrownUsdcWethSleeve(USDC, WETH, ROUTER, Y_MM, Y_V2, address(fhe), HOT);
        fhe.setSleeve(address(sleeve));

        // MetaMorpho allocator = sleeve (can deposit WETH)
        IMMA(Y_MM).setIsAllocator(address(sleeve), true);

        // Vault V2 allocator = sleeve (submit → exec)
        bytes memory data = abi.encodeCall(IV2A.setIsAllocator, (address(sleeve), true));
        IV2A(Y_V2).submit(data);
        IV2A(Y_V2).setIsAllocator(address(sleeve), true);

        vm.stopBroadcast();

        console2.log("CrownFhePrivateVaultV2", address(fhe));
        console2.log("CrownUsdcWethSleeve", address(sleeve));
        console2.log("mmAllocatorSleeve", IMMA(Y_MM).isAllocator(address(sleeve)) ? 1 : 0);
        console2.log("v2AllocatorSleeve", IV2A(Y_V2).isAllocator(address(sleeve)) ? 1 : 0);
        console2.log("perfBps", fhe.performanceFeeBps());
        console2.log("mgmtBps", fhe.managementFeeBps());
    }
}
