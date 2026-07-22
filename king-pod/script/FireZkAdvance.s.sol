// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkAdvance} from "../src/CrownZkAdvance.sol";

interface IPsmU {
    function unstockKusd(uint256 amt, address to) external;
    function kusdStock() external view returns (uint256);
}

interface IERC20U {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IGateU {
    function isProven(address) external view returns (bool);
}

/// @notice Deploy ZK-gated advance door + move kUSD inventory from PSM.
/// @dev KING_OK=1 FIRE_ZK_ADVANCE=1
contract FireZkAdvance is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant COLD = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KUSD = 0x0FEA62084A024544891f03035E85401C2C886c1b;
    address constant GATE = 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205;
    address constant PSM = 0x3fbBBd4c00AE3f40762Bf58Ccbbff92ec3FF4eCf;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_ADVANCE", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IGateU(GATE).isProven(HOT), "ZK_REQUIRED");

        uint256 move = vm.envOr("STOCK_KUSD", uint256(700_000e6));
        uint256 psmBal = IPsmU(PSM).kusdStock();
        if (move > psmBal) move = psmBal;

        vm.startBroadcast(pk);

        CrownZkAdvance adv = new CrownZkAdvance(USDC, KUSD, GATE, HOT, COLD, HOT);
        console2.log("CrownZkAdvance", address(adv));

        if (move > 0) {
            IPsmU(PSM).unstockKusd(move, HOT);
            IERC20U(KUSD).approve(address(adv), move);
            adv.stockKusd(move);
            console2.log("stockedKusd", move);
        }

        vm.stopBroadcast();

        (bool proven, uint256 avail, uint256 thr) = adv.quote();
        console2.log("zkProven", proven);
        console2.log("kusdAvailable", avail);
        console2.log("threshold", thr);
        console2.log("PRIMARY_FILL", "advance(usdc) reverts if King not proven");
    }
}
