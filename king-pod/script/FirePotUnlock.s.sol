// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownDebtRepayUnlock} from "../src/CrownDebtRepayUnlock.sol";

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IYeleU {
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @notice Hot-owned yELE-K unlock. KING_GO=1 FIRE_POT_UNLOCK=1
/// @dev Flash repay king 77% debt → redeem shares → Morpho pulls flash.
///      Matched pot ⇒ net ops USDC ≈ 0; share trap cleared.
contract FirePotUnlock is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_POT_UNLOCK", uint256(0)) == 1, "NEED FIRE_POT_UNLOCK=1");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "HOT");

        uint256 shares = IYeleU(YELE_K).balanceOf(HOT);
        require(shares > 0, "NO_SHARES");
        uint256 assets = IYeleU(YELE_K).convertToAssets(shares);
        // Flash exact claim — repay that debt slice → idle ≈ claim → redeem clears.
        uint256 flash = assets;
        console2.log("shares", shares);
        console2.log("assets", assets);
        console2.log("flash", flash);
        console2.log("hotUsdcBefore", IERC20U(USDC).balanceOf(HOT));

        vm.startBroadcast(hotPk);
        CrownDebtRepayUnlock h = new CrownDebtRepayUnlock(HOT, YELE_K);
        console2.log("helper", address(h));
        IERC20U(YELE_K).approve(address(h), shares);
        h.unlock(flash, shares, HOT, HOT);
        vm.stopBroadcast();

        console2.log("hotUsdcAfter", IERC20U(USDC).balanceOf(HOT));
        console2.log("sharesLeft", IYeleU(YELE_K).balanceOf(HOT));
        console2.log("vaultTA", IYeleU(YELE_K).totalAssets());
        console2.log("POT_UNLOCK_OK", uint256(1));
    }
}
