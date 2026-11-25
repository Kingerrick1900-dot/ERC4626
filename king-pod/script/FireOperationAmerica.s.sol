// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownAmericaCapacity} from "../src/CrownAmericaCapacity.sol";
import {CrownKingdomNav} from "../src/CrownKingdomNav.sol";

interface IZkAttest {
    function commitPayrollRoot(bytes32 root, bool ok) external;
    function attestLive(bytes32 payrollRoot) external returns (uint256);
    function bordersSecure() external view returns (bool);
    function epoch() external view returns (uint256);
}

/// @notice Operation America fire: 100T CAPACITY (no mint) + ZK NAV attest.
contract FireOperationAmerica is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    uint256 constant CAP_100T = 100_000_000_000_000 ether;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownAmericaCapacity cap = new CrownAmericaCapacity(EUSD, HOT, CAP_100T);
        cap.setAttest(ATTEST);

        CrownKingdomNav nav = new CrownKingdomNav(YRSS, EUSD, LANDING, HOT);
        nav.setModules(address(cap), ATTEST);
        bytes32 root = nav.publish();

        cap.setCapacity(CAP_100T, root);

        IZkAttest zk = IZkAttest(ATTEST);
        zk.commitPayrollRoot(root, true);
        uint256 epochId = zk.attestLive(root);

        vm.stopBroadcast();

        (
            uint256 lockedGoldUsd6,
            uint256 idleEusd18,
            uint256 mintedEusd18,
            uint256 capacityEusd18,
            uint256 unlockedEusd18,
            ,
            bytes32 navRoot
        ) = nav.latest();

        console2.log("CrownAmericaCapacity", address(cap));
        console2.log("CrownKingdomNav", address(nav));
        console2.log("capacity", capacityEusd18);
        console2.log("minted", mintedEusd18);
        console2.log("idleLanding", idleEusd18);
        console2.log("lockedGoldUsd6", lockedGoldUsd6);
        console2.log("unlocked", unlockedEusd18);
        console2.log("headroomCapacity", cap.headroomCapacity());
        console2.log("canMint1", cap.canMint(1 ether));
        console2.log("epoch", epochId);
        console2.log("borders", zk.bordersSecure());
        console2.logBytes32(root);
        console2.logBytes32(navRoot);
    }
}
