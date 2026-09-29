// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPSMFiller} from "../src/CrownPSMFiller.sol";

interface IVaultAdmin {
    function setTarget(address target, bool on) external;
}

interface IAgentExec {
    function exec(address target, address token, uint256 amount, bytes calldata data)
        external
        returns (bytes memory);
    function setArmed(bool on) external;
}

interface IERC20a {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy CrownPSMFiller, arm KingAgent vault target, dust-fill LSR if HOT has USDC.
contract FirePsmFiller is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LSR = 0x3edeD70F8ACa4472948E7D3AE3Ad95D63ECdda4F;
    address constant AGENT = 0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA;
    address constant VAULT = 0xc3f2ACe4161B82dbceE08Ea636467D2C3bD72458;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        vm.startBroadcast(pk);

        CrownPSMFiller filler =
            new CrownPSMFiller(LSR, MORPHO, ROUTER, USDC, USDT, EUSD, HOT, HOT);
        filler.setAgent(AGENT);
        filler.setOperator(AGENT, true);
        filler.setOperator(VAULT, true);

        // Arm agent path: vault may pull USDC and call fill
        IVaultAdmin(VAULT).setTarget(address(filler), true);

        uint256 dust = IERC20a(USDC).balanceOf(HOT);
        if (dust > 0) {
            IERC20a(USDC).approve(address(filler), dust);
            filler.fill(USDC, dust);
        }

        vm.stopBroadcast();

        console2.log("CrownPSMFiller", address(filler));
        console2.log("LSR_USDC", IERC20a(USDC).balanceOf(LSR));
        console2.log("filledDust", dust);
    }
}
