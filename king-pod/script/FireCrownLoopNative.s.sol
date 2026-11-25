// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLoopNative} from "../src/CrownLoopNative.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Deploy CrownLoopNative + fire one atomic Morpho flash self-seed on eUSD/USDC.
contract FireCrownLoopNative is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        // Default fire: $100k flash — override with FLASH_USDC / EUSD_COLL
        uint256 flashUsdc = vm.envOr("FLASH_USDC", uint256(100_000e6));
        // coll @ 86% LTV + 2% buffer: flash * 1e12 * 1e18 / lltv * 102/100
        uint256 eusdColl = vm.envOr(
            "EUSD_COLL", (flashUsdc * 1e12 * 1e18 * 102) / (LLTV * 100)
        );

        vm.startBroadcast(pk);

        CrownLoopNative loop = new CrownLoopNative(MORPHO, USDC, EUSD, HOT, ORACLE, IRM, LLTV, HOT);

        IMorphoAuth(MORPHO).setAuthorization(address(loop), true);
        IERC20b(EUSD).approve(address(loop), eusdColl);

        loop.fire(flashUsdc, eusdColl);

        vm.stopBroadcast();

        bytes32 mid = loop.marketId();
        (uint256 supplyShares, uint128 borrowShares, uint128 coll) = IMorphoAuth(MORPHO).position(mid, HOT);
        (uint128 sAssets,, uint128 bAssets,,,) = IMorphoAuth(MORPHO).market(mid);

        console2.log("CrownLoopNative", address(loop));
        console2.log("flashUsdc", flashUsdc);
        console2.log("eusdColl", eusdColl);
        console2.log("hotSupplyShares", supplyShares);
        console2.log("hotBorrowShares", uint256(borrowShares));
        console2.log("hotCollateral", uint256(coll));
        console2.log("marketSupplyAssets", uint256(sAssets));
        console2.log("marketBorrowAssets", uint256(bAssets));
        console2.log("hotUsdc", IERC20b(USDC).balanceOf(HOT));
        console2.log("fires", loop.fires());
    }
}
