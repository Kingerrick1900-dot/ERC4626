// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGold} from "../src/CrownGold.sol";
import {CrownFixedOracle} from "../src/CrownFixedOracle.sol";
import {CrownGoldCdp} from "../src/scroll/CrownGoldCdp.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownSpoilsDominion} from "../src/scroll/CrownSpoilsDominion.sol";

/// @notice KING_GO=1 FIRE_SCROLL_GOLD=1 — fork gold rails to Scroll (no Morpho; Elepan-native).
/// @dev Base untouched. kXAU is the power highlight behind the kingdom token surface.
contract FireScrollGold is Script {
    uint256 constant SCROLL_CHAIN = 534352;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant SCROLL_LANDING = 0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f;
    address constant SCROLL_EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant SCROLL_SPOILS = 0x8E5ff2552f8fE0730E89dA7fBF1721f910615DcD;
    uint256 constant PRICE_10 = 1e35;
    uint256 constant MINT_KXAU = 100_001e8; // mirror Base free treasury — sovereign gold power

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SCROLL_GOLD", uint256(0)) == 1, "NEED FIRE_SCROLL_GOLD=1");
        require(block.chainid == SCROLL_CHAIN, "NOT_SCROLL");

        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == SCROLL_HOT, "SCROLL_HOT");

        console2.log("domain", "SCROLL_GOLD_RAILS");
        console2.log("BASE_UNTOUCHED", uint256(1));

        vm.startBroadcast(pk);

        CrownGold gold = new CrownGold(SCROLL_HOT);
        CrownFixedOracle oracle = new CrownFixedOracle(PRICE_10);
        require(oracle.price() == PRICE_10, "ORACLE_10");

        CrownGoldCdp cdp = new CrownGoldCdp(
            address(gold), SCROLL_EUSD, address(oracle), SCROLL_HOT, SCROLL_LANDING, SCROLL_HOT
        );
        CrownElepanUsd(SCROLL_EUSD).setMinter(address(cdp), true);

        gold.mint(SCROLL_HOT, MINT_KXAU);

        // Re-wire spoils with gold highlight addresses in event surface via capacity tag
        CrownSpoilsDominion(SCROLL_SPOILS).recordSpoil(0, keccak256("GOLD_RAILS_LIVE"));

        vm.stopBroadcast();

        console2.log("gold", address(gold));
        console2.log("oracle", address(oracle));
        console2.log("goldCdp", address(cdp));
        console2.log("oraclePrice", oracle.price());
        console2.log("hotKxau", gold.balanceOf(SCROLL_HOT));
        console2.log("totalKxau", gold.totalSupply());
        console2.log("cdpMinter", CrownElepanUsd(SCROLL_EUSD).isMinter(address(cdp)) ? uint256(1) : uint256(0));
        console2.log("SCROLL_GOLD_OK", uint256(1));
    }
}
