// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IZkCreditL {
    function setLltv(uint256) external;
    function lltv() external view returns (uint256);
    function maxBorrow(address) external view returns (uint256);
}

interface IGateL {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, bool);
}

/// @notice Arm credit for FULL $700k draw against ZK attestation (LLTV 100%).
/// @dev KING_OK=1 FIRE_SECURE_700K=1
contract FireSecure700k is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant CREDIT = 0xeAE626b6e82E51c9805D72B6532A948dcf57D392;
    address constant GATE = 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_SECURE_700K", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        require(IGateL(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 thr,, bool valid) = IGateL(GATE).attestations(HOT);
        require(valid && thr >= 700_000e6, "BAD_ATT");

        vm.startBroadcast(pk);
        // 100% of attested $700k → maxBorrow = $700k when credit is funded
        IZkCreditL(CREDIT).setLltv(1e18);
        vm.stopBroadcast();

        console2.log("lltv", IZkCreditL(CREDIT).lltv());
        console2.log("threshold", thr);
        console2.log("maxBorrowNow", IZkCreditL(CREDIT).maxBorrow(HOT));
        console2.log("SECURE_700K_ARMED", uint256(1));
    }
}
