// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";

interface IZkCreditV {
    function setLltv(uint256) external;
    function lltv() external view returns (uint256);
    function borrowTo(address to, uint256 amt) external;
    function maxBorrow(address) external view returns (uint256);
    function gate() external view returns (address);
}

interface IGateV {
    function isProven(address) external view returns (bool);
}

interface IERC20V {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy credit V2 with atomic borrowTo(cold). Optional immediate draw.
/// @dev KING_OK=1 FIRE_ATOMIC_COLD=1
///      DEPLOY=1 (default) · DRAW=1 to borrowTo cold if liquidity exists
contract FireZkAtomicCold is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant COLD = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ATOMIC_COLD", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IGateV(GATE).isProven(HOT), "NOT_PROVEN");

        bool deploy = vm.envOr("DEPLOY", uint256(1)) == 1;
        uint256 want = vm.envOr("BORROW_AMT", uint256(700_000e6));

        vm.startBroadcast(pk);

        address creditAddr;
        if (deploy) {
            CrownZkCredit credit = new CrownZkCredit(USDC, GATE, HOT, HOT);
            credit.setLltv(1e18); // full $700k against attestation
            creditAddr = address(credit);
            console2.log("CrownZkCreditV2", creditAddr);
        } else {
            creditAddr = vm.envAddress("CREDIT");
        }

        IZkCreditV c = IZkCreditV(creditAddr);
        console2.log("lltv", c.lltv());
        console2.log("maxBorrow", c.maxBorrow(HOT));
        console2.log("creditUsdc", IERC20V(USDC).balanceOf(creditAddr));

        if (vm.envOr("DRAW", uint256(0)) == 1) {
            uint256 maxB = c.maxBorrow(HOT);
            require(maxB > 0, "NO_CREDIT_LIQUIDITY");
            uint256 amt = want > maxB ? maxB : want;
            uint256 coldBefore = IERC20V(USDC).balanceOf(COLD);
            // one tx: borrow → cold, else full revert
            c.borrowTo(COLD, amt);
            uint256 coldAfter = IERC20V(USDC).balanceOf(COLD);
            require(coldAfter >= coldBefore + amt, "COLD_MISS");
            console2.log("ATOMIC_DRAW", amt);
            console2.log("coldUsdc", coldAfter);
        }

        vm.stopBroadcast();
        console2.log("COLD", COLD);
        console2.log("ATOMIC_COLD_ARMED", uint256(1));
    }
}
