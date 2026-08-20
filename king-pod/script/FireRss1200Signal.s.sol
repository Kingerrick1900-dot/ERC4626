// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRss1200Signal} from "../src/CrownRss1200Signal.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuthS {
    function setAuthorization(address, bool) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Claim RSS/$1200 $200M matched book (signal). Unwind helper stays authorized.
/// @dev KING_OK=1 FIRE_SIGNAL=1
///      Unwind anytime: FIRE_UNWIND=1 forge script script/UnwindRss1200Signal.s.sol
contract FireRss1200Signal is Script {
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
    error FLASH();
    error HEADROOM();

    function run() external {
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();

        uint256 ask = vm.envOr("SEED_USDC", uint256(200_000_000e6));
        uint256 coll = vm.envOr("COLL_RSS", uint256(250_000 ether));
        address existing = vm.envOr("SIGNAL", address(0));

        uint256 rssFree = IERC20S(RSS).balanceOf(HOT);
        console2.log("rssFreeBefore", rssFree);
        console2.log("hotUsdc", IERC20S(USDC).balanceOf(HOT));
        console2.log("ask", ask);
        console2.log("collRss", coll);
        if (rssFree < coll + 1_000_000 ether) revert HEADROOM();
        if (IERC20S(USDC).balanceOf(MORPHO) < ask) revert FLASH();
        // Matched book: interest washes (king is both sides). Gas = ETH only. No USDC buffer.

        vm.startBroadcast(pk);

        CrownRss1200Signal z;
        if (existing == address(0) || existing.code.length == 0) {
            z = new CrownRss1200Signal(MORPHO, USDC, RSS, HOT, MID, ORACLE, IRM, LLTV);
            IMorphoAuthS(MORPHO).setAuthorization(address(z), true);
            console2.log("signal", address(z));
            console2.log("authLeftOn", uint256(1));
        } else {
            z = CrownRss1200Signal(existing);
            IMorphoAuthS(MORPHO).setAuthorization(address(z), true);
            console2.log("reuse", address(z));
        }

        IERC20S(RSS).approve(address(z), coll);
        // Optional wei cover only — matched book needs no $2k USDC buffer.
        uint256 dust = IERC20S(USDC).balanceOf(HOT);
        if (dust > 0) IERC20S(USDC).approve(address(z), dust);

        if (vm.envOr("FIRE_SIGNAL", uint256(0)) == 1) {
            z.seed(ask, coll);
        }

        // Unwind stays armed — do NOT revoke Morpho auth.
        vm.stopBroadcast();

        (, uint128 bor, uint128 collPos) = IMorphoAuthS(MORPHO).position(MID, HOT);
        (uint128 tsa,, uint128 tba,,,) = IMorphoAuthS(MORPHO).market(MID);
        console2.log("supplyAssets", uint256(tsa));
        console2.log("borrowAssets", uint256(tba));
        console2.log("hotBorShares", uint256(bor));
        console2.log("hotCollRss", uint256(collPos));
        console2.log("hotRssFree", IERC20S(RSS).balanceOf(HOT));
        console2.log("hfWad", z.hfWad(uint256(collPos), uint256(tba) == 0 ? ask : uint256(tba)));
        console2.log("unwindReady", uint256(1));
        if (vm.envOr("FIRE_SIGNAL", uint256(0)) == 1) {
            console2.log("SIGNAL_200M_OK", tba >= ask && collPos >= coll ? uint256(1) : uint256(0));
        } else {
            console2.log("SIGNAL_PREP_OK", uint256(1));
        }
    }
}
