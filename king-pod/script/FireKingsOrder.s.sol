// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKingsFire} from "../src/zk/CrownKingsFire.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";

interface IZkF {
    function isProven(address) external view returns (bool);
}

interface IMorphoF {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface ICreditF {
    function setOperator(address op, bool allowed) external;
    function debtOf(address) external view returns (uint256);
    function king() external view returns (address);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice King Fire Order — ZK mandatory. FIRE_KINGS_ORDER=1 ZK_SHIELD=1
/// @dev MODE=matched (default) | cover (requires HOT USDC ≥ 1.1M)
contract FireKingsOrder is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ZK = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    address constant CREDIT = 0x75279D46F0dA7f91D5283687C1D0a6EF86992e09;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    function run() external {
        require(vm.envOr("FIRE_KINGS_ORDER", uint256(0)) == 1, "FIRE_KINGS_ORDER");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");
        require(vm.envOr("TRANSPARENT_OK", uint256(0)) == 0, "TRANSPARENT_FORBIDDEN");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IZkF(ZK).isProven(HOT), "NOT_PROVEN");

        string memory mode = vm.envOr("MODE", string("matched"));
        bool useCover = keccak256(bytes(mode)) == keccak256(bytes("cover"));
        console2.log("mode", useCover ? uint256(2) : uint256(1));
        console2.log("hotUsdc", IERC20F(USDC).balanceOf(HOT));
        console2.log("zkProven", true);

        vm.startBroadcast(pk);
        CrownKingsFire fire = new CrownKingsFire(MORPHO, USDC, ZK, GATE, CREDIT, HOT, HOT, HOT);
        console2.log("CrownKingsFire", address(fire));
        CrownGateV2(GATE).setOperator(address(fire), true);
        ICreditF(CREDIT).setOperator(address(fire), true);

        if (useCover) {
            IERC20F(USDC).approve(address(fire), type(uint256).max);
            fire.fireWithCover();
        } else {
            fire.fireMatched();
        }
        vm.stopBroadcast();

        (, uint128 gBor, uint128 gColl) = IMorphoF(MORPHO).position(SOV, GATE);
        console2.log("gateColl", uint256(gColl));
        console2.log("gateBorShares", uint256(gBor));
        console2.log("creditDebt", ICreditF(CREDIT).debtOf(useCover ? HOT : address(fire)));
        console2.log("hotUsdcAfter", IERC20F(USDC).balanceOf(HOT));
        console2.log("ZK_SHIELD", uint256(1));
        console2.log("KINGS_FIRE", uint256(1));
        require(uint256(gBor) > 0, "NO_BORROW");
    }
}
