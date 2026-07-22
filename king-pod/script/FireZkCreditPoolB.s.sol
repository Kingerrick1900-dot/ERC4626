// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";

interface IERC20B {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaMorphoB {
    function balanceOf(address) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function asset() external view returns (address);
}

/// @notice B — Redeploy credit w/ borrowTo Landing, seed L from Steak USDC, draw to Landing.
/// @dev KING_OK=1 FIRE_ZK_CREDIT_B=1
contract FireZkCreditPoolB is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183; // Steakhouse USDC MetaMorpho

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_CREDIT_B", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 landBefore = IERC20B(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);

        // 1) Deploy Credit V2 — pool L, cold draw to Landing
        CrownZkCredit credit = new CrownZkCredit(USDC, GATE, HOT, LANDING, HOT);
        console2.log("CrownZkCreditB", address(credit));

        // 2) Redeem Steakhouse USDC → hot (seed inventory for L)
        uint256 shares = IMetaMorphoB(STEAK).maxRedeem(HOT);
        console2.log("steak maxRedeem", shares);
        if (shares > 0) {
            uint256 got = IMetaMorphoB(STEAK).redeem(shares, HOT, HOT);
            console2.log("steak redeemed USDC", got);
        }

        uint256 hotUsdc = IERC20B(USDC).balanceOf(HOT);
        console2.log("hot USDC", hotUsdc);
        require(hotUsdc > 0, "NO_USDC_SEED");

        // 3) Supply into L (path seed — real size needs system suppliers)
        IERC20B(USDC).approve(address(credit), hotUsdc);
        credit.supply(hotUsdc);
        console2.log("L supplied", hotUsdc);
        console2.log("maxBorrow", credit.maxBorrow(HOT));

        // 4) Draw max to Landing (ZK underwrite + cold-or-revert)
        uint256 drawn = credit.borrowMaxToLanding();
        console2.log("drawn to Landing", drawn);

        vm.stopBroadcast();

        uint256 landAfter = IERC20B(USDC).balanceOf(LANDING);
        console2.log("Landing USDC before", landBefore);
        console2.log("Landing USDC after", landAfter);
        console2.log("Landing delta", landAfter - landBefore);
        console2.log("credit bal", IERC20B(USDC).balanceOf(address(credit)));
        console2.log("totalDebt", credit.totalDebt());
        console2.log("CREDIT_B_OK", uint256(1));
    }
}
