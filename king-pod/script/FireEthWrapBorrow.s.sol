// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownDualFlashMachine} from "../src/CrownDualFlashMachine.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoS {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

/// @notice Live fire: wrap native ETH → Morpho WETH/USDC coll → borrow USDC to Landing.
/// @dev Env: PRIVATE_KEY, ETH_IN (wei), USDC_OUT (6dp), optional MACHINE (reuse deployed).
///      MorphoWethLoanProtectionPolicy call shape (Base/Coinbase) + LI.FI equity path C.
contract FireEthWrapBorrow is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS_ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 ethIn = vm.envUint("ETH_IN");
        uint256 usdcOut = vm.envUint("USDC_OUT");
        require(ethIn > 0, "ETH_IN");
        require(HOT.balance >= ethIn, "HOT_ETH_LOW");

        uint256 landBefore = IERC20S(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        address machineAddr = vm.envOr("MACHINE", address(0));
        CrownDualFlashMachine machine;
        if (machineAddr == address(0)) {
            machine = new CrownDualFlashMachine(
                MORPHO, USDC, WETH, RSS, HOT, LANDING, RSS_ORACLE, WETH_ORACLE, IRM
            );
            IMorphoS(MORPHO).setAuthorization(address(machine), true);
        } else {
            machine = CrownDualFlashMachine(payable(machineAddr));
        }
        machine.equityEthBorrow{value: ethIn}(usdcOut);
        vm.stopBroadcast();

        uint256 landAfter = IERC20S(USDC).balanceOf(LANDING);
        console2.log("MACHINE", address(machine));
        console2.log("ETH_IN", ethIn);
        console2.log("USDC_OUT", usdcOut);
        console2.log("LANDING_USDC_BEFORE", landBefore);
        console2.log("LANDING_USDC_AFTER", landAfter);
        console2.log("LANDING_DELTA", landAfter - landBefore);
        console2.log("MODE", machine.lastMode());
    }
}
