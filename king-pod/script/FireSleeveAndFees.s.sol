// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUsdcWethSleeve} from "../src/CrownUsdcWethSleeve.sol";
import {CrownFhePrivateVaultV2} from "../src/CrownFhePrivateVaultV2.sol";

interface IMMA {
    function setIsAllocator(address, bool) external;
    function isAllocator(address) external view returns (bool);
}

interface IV2Fee {
    function submit(bytes memory) external;
    function setIsAllocator(address, bool) external;
    function setPerformanceFee(uint256) external;
    function setManagementFee(uint256) external;
    function setPerformanceFeeRecipient(address) external;
    function setManagementFeeRecipient(address) external;
    function performanceFee() external view returns (uint256);
    function managementFee() external view returns (uint256);
    function performanceFeeRecipient() external view returns (address);
    function managementFeeRecipient() external view returns (address);
    function receiveSharesGate() external view returns (address);
    function sendSharesGate() external view returns (address);
    function receiveAssetsGate() external view returns (address);
    function sendAssetsGate() external view returns (address);
    function isAllocator(address) external view returns (bool);
}

interface IZkCredit {
    function supply(uint256 amt) external;
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Fee fix on VaultV2 + deploy USDC→WETH sleeve + FHE v2 + dust-seed ZK credit.
/// @dev KING_GO=1 FIRE_SLEEVE=1. Gates stay 0x0 (permissionless) unless GATE_KYC set.
contract FireSleeveAndFees is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant Y_MM = 0xfdD5a1d4823411809D6ac735991B3A015E5AaAb5;
    address constant Y_V2 = 0x35a00F116536c13A63273513990E4E496a15Ddb2;
    address constant ZK_CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;

    uint256 constant PERF = 0.1e18; // 10%
    uint256 constant MGMT = 0.01e18; // 1%

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SLEEVE", uint256(0)) == 1, "NEED FIRE_SLEEVE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IV2Fee v2 = IV2Fee(Y_V2);

        vm.startBroadcast(pk);

        // --- Vault V2 fees (submit → exec, timelock 0) ---
        v2.submit(abi.encodeCall(v2.setPerformanceFeeRecipient, (HOT)));
        v2.setPerformanceFeeRecipient(HOT);
        v2.submit(abi.encodeCall(v2.setManagementFeeRecipient, (HOT)));
        v2.setManagementFeeRecipient(HOT);
        v2.submit(abi.encodeCall(v2.setPerformanceFee, (PERF)));
        v2.setPerformanceFee(PERF);
        v2.submit(abi.encodeCall(v2.setManagementFee, (MGMT)));
        v2.setManagementFee(MGMT);

        // --- FHE v2 + sleeve ---
        CrownFhePrivateVaultV2 fhe = new CrownFhePrivateVaultV2(USDC, GATE, HOT, HOT);
        fhe.setFees(1000, 100); // 10% perf / 1% mgmt (bps on FHE vault USDC skim)

        CrownUsdcWethSleeve sleeve =
            new CrownUsdcWethSleeve(USDC, WETH, ROUTER, Y_MM, Y_V2, address(fhe), HOT);
        fhe.setSleeve(address(sleeve));

        // Allocators: sleeve on MM + V2
        IMMA(Y_MM).setIsAllocator(address(sleeve), true);
        v2.submit(abi.encodeCall(v2.setIsAllocator, (address(sleeve), true)));
        v2.setIsAllocator(address(sleeve), true);

        // Dust-seed ZK credit if hot holds USDC
        uint256 dust = IERC20A(USDC).balanceOf(HOT);
        if (dust > 0) {
            IERC20A(USDC).approve(ZK_CREDIT, dust);
            IZkCredit(ZK_CREDIT).supply(dust);
        }

        vm.stopBroadcast();

        console2.log("CrownFhePrivateVaultV2", address(fhe));
        console2.log("CrownUsdcWethSleeve", address(sleeve));
        console2.log("v2Perf", v2.performanceFee());
        console2.log("v2Mgmt", v2.managementFee());
        console2.log("v2PerfRecipient", v2.performanceFeeRecipient());
        console2.log("v2MgmtRecipient", v2.managementFeeRecipient());
        console2.log("gateRecvShares", v2.receiveSharesGate());
        console2.log("gateSendShares", v2.sendSharesGate());
        console2.log("gateRecvAssets", v2.receiveAssetsGate());
        console2.log("gateSendAssets", v2.sendAssetsGate());
        console2.log("mmAllocSleeve", IMMA(Y_MM).isAllocator(address(sleeve)) ? 1 : 0);
        console2.log("v2AllocSleeve", v2.isAllocator(address(sleeve)) ? 1 : 0);
        console2.log("zkCreditDustSeeded", dust);
    }
}
