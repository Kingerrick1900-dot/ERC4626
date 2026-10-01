// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLoopNative} from "../src/CrownLoopNative.sol";

interface IMorphoCap {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20c {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire CrownLoopNative $1M repeatedly until Morpho synth depth >= CAP (default $200M).
/// @dev No pivots. BATCH controls txs per broadcast. Re-run until cap.
contract FireCrownLoopToCap is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LOOP = 0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    bytes32 constant MARKET =
        0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd;
    uint256 constant LLTV = 860000000000000000;
    uint256 constant FLASH = 1_000_000e6; // $1M per fire
    uint256 constant CAP_DEFAULT = 200_000_000e6; // $200M

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 cap = vm.envOr("CAP_USDC", CAP_DEFAULT);
        uint256 batch = vm.envOr("BATCH", uint256(25));
        uint256 eusdColl = (FLASH * 1e12 * 1e18 * 102) / (LLTV * 100);

        CrownLoopNative loop = CrownLoopNative(LOOP);

        (uint128 supplyBefore,,,,,) = IMorphoCap(MORPHO).market(MARKET);
        console2.log("depthBefore", uint256(supplyBefore));
        console2.log("firesBefore", loop.fires());
        console2.log("batch", batch);
        console2.log("cap", cap);

        if (uint256(supplyBefore) >= cap) {
            console2.log("ALREADY_AT_CAP");
            return;
        }

        vm.startBroadcast(pk);
        IERC20c(EUSD).approve(LOOP, eusdColl * batch);

        uint256 fired;
        for (uint256 i = 0; i < batch; i++) {
            (uint128 supply,,,,,) = IMorphoCap(MORPHO).market(MARKET);
            if (uint256(supply) >= cap) break;
            loop.fire(FLASH, eusdColl);
            fired++;
        }
        vm.stopBroadcast();

        (uint128 supplyAfter,,,,,) = IMorphoCap(MORPHO).market(MARKET);
        console2.log("fired", fired);
        console2.log("depthAfter", uint256(supplyAfter));
        console2.log("firesAfter", loop.fires());
        console2.log("totalFlashed", loop.totalFlashed());
        console2.log("hotUsdc", IERC20c(USDC).balanceOf(HOT));
        console2.log("hotEusd", IERC20c(EUSD).balanceOf(HOT));
        console2.log("atCap", uint256(supplyAfter) >= cap);
    }
}
