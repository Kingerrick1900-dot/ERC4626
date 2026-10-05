// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";
import {CrownZkYieldLadder} from "../src/CrownZkYieldLadder.sol";

interface IERC20X {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Deploy Credit(operator)+YieldLadder, wire Steak/Gauntlet, arm draw path.
/// @dev KING_OK=1 FIRE_ZK_LADDER=1
contract FireZkYieldLadder is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_LADDER", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownZkCredit credit = new CrownZkCredit(USDC, GATE, HOT, LANDING, HOT);
        CrownZkYieldLadder ladder = new CrownZkYieldLadder(USDC, HOT, LANDING, HOT);
        ladder.setCredit(address(credit));
        ladder.addRung(STEAK, 6000);
        ladder.addRung(GAUNTLET, 4000);
        credit.setOperator(address(ladder), true);

        console2.log("CreditLadder", address(credit));
        console2.log("YieldLadder", address(ladder));
        console2.log("maxBorrow", credit.maxBorrow(HOT));

        // If any hot USDC, seed ladder and allocate (carry start)
        uint256 hotUsdc = IERC20X(USDC).balanceOf(HOT);
        if (hotUsdc > 0) {
            IERC20X(USDC).approve(address(ladder), hotUsdc);
            ladder.seed(hotUsdc);
            ladder.allocateIdle();
            console2.log("seeded", hotUsdc);
        }

        // If L has liquidity, draw small tranche (≤ $500 or max) into ladder → yield
        uint256 mb = credit.maxBorrow(HOT);
        uint256 tranche = mb;
        uint256 capTranche = 500e6; // small draws per rung policy
        if (tranche > capTranche) tranche = capTranche;
        if (tranche > 0) {
            ladder.drawFromCredit(tranche);
            ladder.allocateIdle();
            console2.log("drew tranche", tranche);
        }

        vm.stopBroadcast();

        console2.log("rung0", ladder.rungAssets(0));
        console2.log("rung1", ladder.rungAssets(1));
        console2.log("LADDER_ARMED", uint256(1));
    }
}
