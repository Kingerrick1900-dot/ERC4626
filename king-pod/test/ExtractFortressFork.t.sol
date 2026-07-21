// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownExtractFortress} from "../src/CrownExtractFortress.sol";

interface IMorphoT {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IYrssT {
    function approve(address, uint256) external returns (bool);
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
}

/// @dev Fork assumes live $500k fortress already on chain (debt + yRSS).
contract ExtractFortressForkTest is Test {
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

    function test_extract_fortress_to_landing_fork() public {
        (, uint128 borBefore,) = IMorphoT(MORPHO).position(RSS77, HOT);
        vm.assume(borBefore > 0);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        CrownExtractFortress ex = new CrownExtractFortress(
            MORPHO, USDC, YRSS, HOT, LANDING, RSS77, RSS, ORACLE, IRM, LLTV, HOT
        );
        IMorphoT(MORPHO).setAuthorization(address(ex), true);
        IYrssT(YRSS).approve(address(ex), type(uint256).max);
        ex.extractToLanding();
        vm.stopPrank();

        uint256 landAfter = IERC20T(USDC).balanceOf(LANDING);
        (, uint128 borAfter, uint128 collAfter) = IMorphoT(MORPHO).position(RSS77, HOT);

        console2.log("landingGain", (landAfter - landBefore) / 1e6);
        console2.log("debtAfter", uint256(borAfter));
        console2.log("collAfter", uint256(collAfter) / 1e18);

        assertEq(uint256(borAfter), 0, "debt zero");
        assertGt(landAfter, landBefore + 400_000e6, "Landing gets ~$500k");
        assertGt(uint256(collAfter), 0, "RSS coll stays posted");
    }
}
