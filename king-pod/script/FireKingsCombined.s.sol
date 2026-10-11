// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKingsCombinedFire} from "../src/zk/CrownKingsCombinedFire.sol";
import {CrownZkYieldLadder} from "../src/CrownZkYieldLadder.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";

interface IZkF {
    function isProven(address) external view returns (bool);
}

interface IMorphoF {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice King Combined Plan fire. FIRE_KINGS_COMBINED=1 ZK_SHIELD=1
/// @dev MODE=matched|cover · cover needs HOT USDC ≥ 2M and deploys ladder
contract FireKingsCombined is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ZK = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    function run() external {
        require(vm.envOr("FIRE_KINGS_COMBINED", uint256(0)) == 1, "FIRE_KINGS_COMBINED");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");
        require(vm.envOr("TRANSPARENT_OK", uint256(0)) == 0, "TRANSPARENT_FORBIDDEN");
        require(vm.envOr("NO_ZK", uint256(0)) == 0, "NO_ZK_FORBIDDEN");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IZkF(ZK).isProven(HOT), "NOT_PROVEN");

        bool cover = keccak256(bytes(vm.envOr("MODE", string("matched")))) == keccak256(bytes("cover"));
        console2.log("mode", cover ? uint256(2) : uint256(1));
        console2.log("hotUsdc", IERC20F(USDC).balanceOf(HOT));
        console2.log("zkProven", true);

        (, uint128 gBorBefore, uint128 gColl) = IMorphoF(MORPHO).position(SOV, GATE);
        console2.log("gateColl", uint256(gColl));
        console2.log("gateBorBefore", uint256(gBorBefore));
        require(uint256(gColl) > 0, "NO_COLLATERAL");

        vm.startBroadcast(pk);

        CrownKingsCombinedFire fire =
            new CrownKingsCombinedFire(MORPHO, USDC, ZK, GATE, HOT, HOT, HOT);
        console2.log("CrownKingsCombinedFire", address(fire));
        CrownGateV2(GATE).setOperator(address(fire), true);

        if (cover) {
            CrownZkYieldLadder ladder = new CrownZkYieldLadder(USDC, HOT, HOT, HOT);
            ladder.addRung(STEAK, 6000);
            ladder.addRung(GAUNTLET, 4000);
            fire.setLadder(address(ladder));
            console2.log("YieldLadder", address(ladder));
            IERC20F(USDC).approve(address(fire), type(uint256).max);
            fire.fireWithCover();
            // Engine USDC landed on ladder idle in-callback; King allocates to Steak/Gauntlet
            ladder.allocateIdle();
        } else {
            fire.fireMatched();
        }

        vm.stopBroadcast();

        (, uint128 gBorAfter,) = IMorphoF(MORPHO).position(SOV, address(GATE));
        (uint256 fireSup,,) = IMorphoF(MORPHO).position(SOV, address(fire));
        console2.log("gateBorAfter", uint256(gBorAfter));
        console2.log("engineLpShares", fireSup);
        console2.log("hotUsdcAfter", IERC20F(USDC).balanceOf(HOT));
        console2.log("ZK_SHIELD", uint256(1));
        console2.log("KINGS_COMBINED", uint256(1));
        require(uint256(gBorAfter) > uint256(gBorBefore), "NO_NEW_DEBT");
    }
}
