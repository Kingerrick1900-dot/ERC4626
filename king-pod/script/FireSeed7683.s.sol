// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";
import {CrownLitePsm} from "../src/prime/CrownLitePsm.sol";
import {CrownBoundLandingCollateral} from "../src/prime/CrownBoundLandingCollateral.sol";

/// @notice Seed 7683 + LitePSM, set 10% discount, lock gUSD for draw capacity.
/// @dev HOT is EIP-7702 — prefer `FireSeed7683Cast.sh` one-tx-at-a-time for live fire.
contract FireSeed7683 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;

    address constant FILL = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;
    address constant LITEPSM = 0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B;
    address constant COLL = 0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8;

    uint256 constant SEED_EUSD = 5_000_000e18;
    uint256 constant SEED_PSM = 2_000_000e18;
    uint256 constant LOCK_GUSD = 1_000_000_000e18;
    uint256 constant ORDER_EUSD = 5_000_000e18;
    uint256 constant MAX_USDC_IN = 4_500_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownPrime7683Fill(FILL).setFees(1000, 10);
        CrownLitePsm(LITEPSM).seedEusd(SEED_PSM);
        CrownPrime7683Fill(FILL).seedFillBuffer(SEED_EUSD);
        bytes32 oid = CrownPrime7683Fill(FILL).openOrder(HOT, ORDER_EUSD, MAX_USDC_IN, uint32(block.timestamp + 7 days));
        CrownBoundLandingCollateral(COLL).lockGusd(LOCK_GUSD);

        vm.stopBroadcast();
        console2.log("orderId", vm.toString(oid));
    }
}
