// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRss1200Signal} from "../src/CrownRss1200Signal.sol";

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoU {
    function setAuthorization(address, bool) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @notice Self-del / self-liq the RSS/$1200 signal book. RSS back to HOT.
/// @dev KING_OK=1 FIRE_UNWIND=1 SIGNAL=<CrownRss1200Signal>
///      If SIGNAL unset, deploys a fresh unwind chassis (same as original FireSelfDel1200).
contract UnwindRss1200Signal is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    error NOT_HOT();
    error NO_GO();

    function run() external {
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();
        if (vm.envOr("FIRE_UNWIND", uint256(0)) != 1) revert NO_GO();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();

        address existing = vm.envOr("SIGNAL", address(0));
        uint256 rssBefore = IERC20U(RSS).balanceOf(HOT);
        (, uint128 borBefore, uint128 collBefore) = IMorphoU(MORPHO).position(MID, HOT);
        console2.log("collBefore", uint256(collBefore));
        console2.log("borSharesBefore", uint256(borBefore));

        vm.startBroadcast(pk);

        CrownRss1200Signal z;
        if (existing != address(0) && existing.code.length > 0) {
            z = CrownRss1200Signal(existing);
            IMorphoU(MORPHO).setAuthorization(address(z), true);
            console2.log("unwindVia", address(z));
        } else {
            z = new CrownRss1200Signal(MORPHO, USDC, RSS, HOT, MID, ORACLE, IRM, LLTV);
            IMorphoU(MORPHO).setAuthorization(address(z), true);
            console2.log("unwindDeployed", address(z));
        }

        // Matched book washes — no $2k buffer. Approve whatever dust hot holds for 1-wei cover.
        uint256 dust = IERC20U(USDC).balanceOf(HOT);
        if (dust > 0) IERC20U(USDC).approve(address(z), dust);
        z.unwind();
        IMorphoU(MORPHO).setAuthorization(address(z), false);
        if (dust > 0) IERC20U(USDC).approve(address(z), 0);

        vm.stopBroadcast();

        (uint256 sup, uint128 bor, uint128 coll) = IMorphoU(MORPHO).position(MID, HOT);
        console2.log("hotSupShares", sup);
        console2.log("hotBorShares", uint256(bor));
        console2.log("hotCollRss", uint256(coll));
        console2.log("hotRssFree", IERC20U(RSS).balanceOf(HOT));
        console2.log("rssDelta", IERC20U(RSS).balanceOf(HOT) - rssBefore);
        console2.log("SELF_DEL_OK", (bor == 0 && coll == 0 && sup == 0) ? uint256(1) : uint256(0));
    }
}
