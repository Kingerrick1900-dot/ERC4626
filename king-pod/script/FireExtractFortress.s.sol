// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownExtractFortress} from "../src/CrownExtractFortress.sol";

interface IMorphoE {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IYrssE {
    function approve(address, uint256) external returns (bool);
}

interface IERC20E {
    function balanceOf(address) external view returns (uint256);
}

/// @notice FINISH THE LOOP — unwind $500k fortress → USDC on Landing. No King debit.
/// @dev KING_OK=1 KING_GO=1 FIRE_EXTRACT=1
contract FireExtractFortress is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        bool doFire = vm.envOr("FIRE_EXTRACT", uint256(0)) == 1;
        address existing = vm.envOr("EXTRACTOR", address(0));

        uint256 landBefore = IERC20E(USDC).balanceOf(LANDING);
        (, uint128 borBefore, uint128 collBefore) = IMorphoE(MORPHO).position(RSS77, HOT);

        console2.log("=== EXTRACT FORTRESS TO LANDING ===");
        console2.log("debtSharesBefore", uint256(borBefore));
        console2.log("collBefore", uint256(collBefore));
        console2.log("landingBefore", landBefore);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        require(uint256(borBefore) > 0, "NO FORTRESS DEBT");

        vm.startBroadcast(pk);

        CrownExtractFortress extractor;
        if (existing == address(0)) {
            extractor = new CrownExtractFortress(MORPHO, USDC, YRSS, HOT, LANDING, RSS77, RSS, ORACLE, IRM, LLTV, HOT);
            console2.log("extractor", address(extractor));
        } else {
            extractor = CrownExtractFortress(existing);
        }

        if (!IMorphoE(MORPHO).isAuthorized(HOT, address(extractor))) {
            IMorphoE(MORPHO).setAuthorization(address(extractor), true);
        }
        IYrssE(YRSS).approve(address(extractor), type(uint256).max);

        if (doFire) {
            extractor.extractToLanding();
        }

        vm.stopBroadcast();

        uint256 landAfter = IERC20E(USDC).balanceOf(LANDING);
        (, uint128 borAfter, uint128 collAfter) = IMorphoE(MORPHO).position(RSS77, HOT);

        console2.log("=== EXTRACT RESULT ===");
        console2.log("landingAfter", landAfter);
        console2.log("landingGain", landAfter - landBefore);
        console2.log("debtSharesAfter", uint256(borAfter));
        console2.log("collAfter", uint256(collAfter));
        console2.log("EXTRACT_OK", doFire ? uint256(1) : uint256(0));
    }
}
