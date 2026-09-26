// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownMigrateYrss} from "../src/CrownMigrateYrss.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoQ {
    function setSupplyQueue(bytes32[] calldata ids) external;
    function supplyQueue(uint256) external view returns (bytes32);
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
}

/// @notice Elite migrate: PARK-first queue → deploy CrownMigrateYrss → authorize → peel HOT Morpho supply into yRSS.
/// @dev FIRE=1 to execute migrate. AMOUNT_USDC=0 (default) = max − $1k dust.
contract FireMigrateYrss is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    // PARK ($1200 fixed oracle) — the gold rail
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    // Keep secondary rails after PARK
    bytes32 constant Q1 = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;
    bytes32 constant Q2 = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;
    bytes32 constant Q3 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant Q4 = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant Q5 = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant Q6 = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        bool doFire = vm.envOr("FIRE", uint256(0)) == 1;
        uint256 amount = vm.envOr("AMOUNT_USDC", uint256(0)); // 0 = max
        address existing = vm.envOr("MIGRATOR", address(0));

        (uint256 hs,,) = IMorphoAuth(MORPHO).position(PARK, HOT);
        (uint128 tsa, uint128 tss,,,,) = IMorphoAuth(MORPHO).market(PARK);
        uint256 hotSupply = tss == 0 ? 0 : (hs * uint256(tsa)) / uint256(tss);
        uint256 yrssBefore = IMetaMorphoQ(YRSS).convertToAssets(IMetaMorphoQ(YRSS).balanceOf(HOT));
        (uint184 cap,,) = IMetaMorphoQ(YRSS).config(PARK);

        console2.log("hotSupplyUSDC", hotSupply);
        console2.log("yrssAssetsBefore", yrssBefore);
        console2.log("parkCap", uint256(cap));
        console2.log("doFire", doFire ? uint256(1) : uint256(0));
        console2.log("amount", amount);

        vm.startBroadcast(pk);

        // PARK first — deposits must hit the gold rail
        if (IMetaMorphoQ(YRSS).supplyQueue(0) != PARK) {
            bytes32[] memory q = new bytes32[](7);
            q[0] = PARK;
            q[1] = Q1;
            q[2] = Q2;
            q[3] = Q3;
            q[4] = Q4;
            q[5] = Q5;
            q[6] = Q6;
            IMetaMorphoQ(YRSS).setSupplyQueue(q);
            console2.log("queueParkFirst", uint256(1));
        }

        CrownMigrateYrss mig;
        if (existing == address(0)) {
            mig = new CrownMigrateYrss(MORPHO, USDC, YRSS, HOT, PARK, RSS, ORACLE, IRM, LLTV, HOT);
            console2.log("migrator", address(mig));
        } else {
            mig = CrownMigrateYrss(existing);
            console2.log("migratorExisting", existing);
        }

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(mig))) {
            IMorphoAuth(MORPHO).setAuthorization(address(mig), true);
            console2.log("authorized", uint256(1));
        }

        if (doFire) {
            mig.migrate(amount);
        }

        vm.stopBroadcast();

        (uint256 hs2,,) = IMorphoAuth(MORPHO).position(PARK, HOT);
        (uint128 tsa2, uint128 tss2,,,,) = IMorphoAuth(MORPHO).market(PARK);
        uint256 hotAfter = tss2 == 0 ? 0 : (hs2 * uint256(tsa2)) / uint256(tss2);
        uint256 yrssAfter = IMetaMorphoQ(YRSS).convertToAssets(IMetaMorphoQ(YRSS).balanceOf(HOT));
        console2.log("hotSupplyAfter", hotAfter);
        console2.log("yrssAssetsAfter", yrssAfter);
        console2.log("migratedApprox", yrssAfter > yrssBefore ? yrssAfter - yrssBefore : 0);
    }
}
