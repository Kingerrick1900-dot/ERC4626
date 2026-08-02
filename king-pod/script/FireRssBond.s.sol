// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssBond} from "../src/CrownRssBond.sol";

/// @notice Deploy/arm RSS bond — TOKEN AS CAPITAL. Refuses broadcast without King OK.
/// @dev KING_OK=1 and FIRE_BOND=1 required for any broadcast (LIVE-FIRE-LAW).
contract FireRssBond is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        // Hard gate: King must set KING_OK=1 (stronger than KING_GO theater)
        require(vm.envOr("KING_OK", uint256(0)) == 1, "LIVE-FIRE-LAW: need KING_OK=1");
        bool doFire = vm.envOr("FIRE_BOND", uint256(0)) == 1;

        uint256 price = vm.envOr("BOND_PRICE", uint256(0.97e6)); // $0.97
        uint256 stockRss = vm.envOr("BOND_STOCK", uint256(520_000 ether)); // ~$500k at $0.97
        uint256 phase1 = vm.envOr("PHASE1_USDC", uint256(500_000e6));
        address existing = vm.envOr("BOND", address(0));

        console2.log("=== RSS BOND (token-as-capital) ===");
        console2.log("priceUsdcPerRss", price);
        console2.log("stockRss", stockRss);
        console2.log("phase1Target", phase1);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        if (!doFire) {
            console2.log("DRY: would deploy/arm bond. Set FIRE_BOND=1 + KING_OK=1 to broadcast");
            console2.log("READY", uint256(0));
            return;
        }

        vm.startBroadcast(pk);
        CrownRssBond bond;
        if (existing == address(0)) {
            bond = new CrownRssBond(RSS, USDC, HOT, HOT);
            console2.log("bond", address(bond));
        } else {
            bond = CrownRssBond(existing);
            console2.log("bondExisting", existing);
        }
        IERC20B(RSS).approve(address(bond), stockRss);
        bond.stock(stockRss);
        bond.arm(LANDING, price, phase1, true);
        vm.stopBroadcast();

        console2.log("rssForBond", bond.rssForBond());
        console2.log("quote500kUsdc", bond.quoteRss(500_000e6));
        console2.log("READY", uint256(1));
    }
}

interface IERC20B {
    function approve(address, uint256) external returns (bool);
}
