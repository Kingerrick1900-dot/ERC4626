// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownYelepanStream} from "../src/CrownYelepanStream.sol";

interface IERC20E {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Morpho cold-start: deploy + fund Kingdom Elepan stream for yELEPAN depositors.
/// @dev No Merkl whitelist. No external USDC pre-req.
///      KING_GO=1 FIRE_EMIT=1.
///      Defaults: 4_000_000 Elepan / 28 days (same budget class as Merkl amp).
///      Morpho forum 90-day schedule available via DURATION_SEC + BUDGET_ELEPAN overrides.
contract FireOwnElepanEmit is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;

    uint256 constant DEFAULT_BUDGET = 4_000_000e8; // 4M Elepan (8dp)
    uint256 constant DEFAULT_DURATION = 28 days;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_EMIT", uint256(0)) == 1, "NEED FIRE_EMIT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 budget = vm.envOr("BUDGET_ELEPAN", DEFAULT_BUDGET);
        uint256 duration = vm.envOr("DURATION_SEC", DEFAULT_DURATION);
        require(budget > 0 && duration > 0, "PARAMS");
        require(IERC20E(ELEPAN).balanceOf(HOT) >= budget, "ELEPAN_BUDGET");

        address existing = vm.envOr("STREAM", address(0));

        vm.startBroadcast(pk);
        CrownYelepanStream stream;
        if (existing == address(0)) {
            stream = new CrownYelepanStream(ELEPAN, YELE, HOT);
            stream.setBlacklist(LANDING, true);
            stream.setBlacklist(HOT, true);
        } else {
            stream = CrownYelepanStream(existing);
            require(stream.owner() == HOT, "STREAM_OWNER");
        }

        IERC20E(ELEPAN).approve(address(stream), budget);
        stream.notifyRewardAmount(budget, duration);
        vm.stopBroadcast();

        console2.log("STREAM", address(stream));
        console2.log("YELE", YELE);
        console2.log("BUDGET_ELEPAN", budget);
        console2.log("DURATION_SEC", duration);
        console2.log("REWARD_RATE", stream.rewardRate());
        console2.log("PERIOD_FINISH", stream.periodFinish());
        console2.log("ELIGIBLE_SUPPLY", stream.eligibleSupply());
        console2.log("OWN_ELEPAN_EMIT_FIRE_OK", uint256(1));
    }
}
