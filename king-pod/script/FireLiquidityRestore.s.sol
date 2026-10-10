// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLiquidityRestore} from "../src/CrownLiquidityRestore.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @notice Deploy + fire CrownLiquidityRestore (swap-leg close).
/// @dev KING_OK=1 FIRE_LIQUIDITY_RESTORE=1 FLASH_ALLOWED=1
///      REPAY_SOURCE=UniV3.exactInputSingle(eUSD→USDC fee=500)
contract FireLiquidityRestore is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;
    // Uni V3 SwapRouter02 + QuoterV2 on Base
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant QUOTER = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;
    uint24 constant FEE = 500;

    bytes32 constant SYNTH = 0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_LIQUIDITY_RESTORE", uint256(0)) == 1, "NO_FIRE");
        require(vm.envOr("FLASH_ALLOWED", uint256(0)) == 1, "NO_FLASH");
        string memory src = vm.envOr("REPAY_SOURCE", string(""));
        require(bytes(src).length > 0, "NEED_REPAY_SOURCE");

        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (, uint128 borShares, uint128 coll) = IMorphoAuth(MORPHO).position(SYNTH, HOT);
        console2.log("REPAY_SOURCE", src);
        console2.log("borShares", uint256(borShares));
        console2.log("collEusd", uint256(coll));

        vm.startBroadcast(pk);

        CrownLiquidityRestore restore = new CrownLiquidityRestore(
            MORPHO, ROUTER, QUOTER, USDC, EUSD, HOT, ORACLE, IRM, LLTV, FEE, HOT
        );

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(restore))) {
            IMorphoAuth(MORPHO).setAuthorization(address(restore), true);
        }

        // minToHot=0 — prove wire; depth gate inside restore()
        if (borShares > 0 && coll > 0) {
            restore.restore(0, 0);
        } else {
            console2.log("SKIP_FIRE", "NO_POS");
        }

        vm.stopBroadcast();

        console2.log("CrownLiquidityRestore", address(restore));
        console2.log("RESTORE_DEPLOYED", uint256(1));
    }
}
