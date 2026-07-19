// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRecoverElephant} from "../src/CrownSelfSeedV2.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Deploy recovery freer + optional repayAndFree. Gated.
/// @dev PREP: no KING_GO. EXECUTE: KING_GO=1 FIRE_RECOVER=1 (needs USDC on hot to repay debt).
contract FireRecoverElephant is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "hot");
        bool kingGo = vm.envOr("KING_GO", uint256(0)) == 1;
        bool fire = vm.envOr("FIRE_RECOVER", uint256(0)) == 1;
        address existing = vm.envOr("RECOVERER", address(0));

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(MARKET_ID, HOT);
        console2.log("hotBorrowShares", uint256(bor));
        console2.log("hotColl", uint256(coll));
        console2.log("hotUSDC", IERC20S(USDC).balanceOf(HOT));

        vm.startBroadcast(pk);

        CrownRecoverElephant recoverer;
        if (existing == address(0)) {
            recoverer = new CrownRecoverElephant(MORPHO, USDC, RSS, HOT, MARKET_ID, ORACLE, IRM, LLTV, HOT);
            console2.log("recoverer", address(recoverer));
        } else {
            recoverer = CrownRecoverElephant(existing);
        }

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(recoverer))) {
            IMorphoAuth(MORPHO).setAuthorization(address(recoverer), true);
        }

        if (kingGo && fire) {
            if (bor > 0) {
                IERC20S(USDC).approve(address(recoverer), type(uint256).max);
                recoverer.repayAndFree();
            } else if (coll > 0) {
                recoverer.freeCollateralOnly();
            } else {
                console2.log("nothing to recover");
            }
        } else {
            console2.log("ARMED recoverer only (need KING_GO=1 FIRE_RECOVER=1)");
        }

        vm.stopBroadcast();
    }
}
