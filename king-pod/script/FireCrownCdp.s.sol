// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKusd} from "../src/CrownKusd.sol";
import {CrownCdp} from "../src/CrownCdp.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice ENGINEER 1 — Deploy CDP + open King position (mint kUSD @ Fixed $1).
/// @dev KING_OK=1 FIRE_CDP=1
///      DEPLOY=1 (default) COLL_RSS (default 1_000_000e18) MINT_KUSD (default max at 70%)
contract FireCrownCdp is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_CDP", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        require(me == HOT, "NOT_HOT");

        uint256 coll = vm.envOr("COLL_RSS", uint256(1_000_000 ether));
        bool deploy = vm.envOr("DEPLOY", uint256(1)) == 1;

        vm.startBroadcast(pk);

        CrownKusd kusd;
        CrownCdp cdp;
        if (deploy) {
            kusd = new CrownKusd(HOT);
            cdp = new CrownCdp(RSS, address(kusd), HOT, HOT);
            kusd.setMinter(address(cdp));
            console2.log("kUSD", address(kusd));
            console2.log("CDP", address(cdp));
        } else {
            kusd = CrownKusd(vm.envAddress("KUSD"));
            cdp = CrownCdp(vm.envAddress("CDP"));
        }

        uint256 mintAmt = vm.envOr("MINT_KUSD", uint256(0));
        if (mintAmt == 0) {
            // 70% of coll @ $1 → coll * 0.7 * 1e6 / 1e18
            mintAmt = (coll * 700000) / 1e18; // = coll/1e18 * 0.7e6
        }

        IERC20F(RSS).approve(address(cdp), coll);
        cdp.open(coll, mintAmt);

        console2.log("coll", coll);
        console2.log("mintedKusd", mintAmt);
        console2.log("kusdBal", kusd.balanceOf(HOT));
        console2.log("maxMintLeft", cdp.maxMint(HOT));

        vm.stopBroadcast();
    }
}
