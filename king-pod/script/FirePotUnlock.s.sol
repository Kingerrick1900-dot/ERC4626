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
    function maxWithdraw(address) external view returns (uint256);
}

interface IMorphoU {
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice Hot yELE-K unlock. KING_GO=1 FIRE_POT_UNLOCK=1
/// @dev Matched pot ⇒ net ops USDC ≈ 0; share claim reduced by withdrawn amount.
contract FirePotUnlock is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_POT_UNLOCK", uint256(0)) == 1, "NEED FIRE_POT_UNLOCK=1");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "HOT");

        uint256 shares = IYeleU(YELE_K).balanceOf(HOT);
        require(shares > 0, "NO_SHARES");
        uint256 claim = IYeleU(YELE_K).convertToAssets(shares);
        // Size flash to vault's ELE Morpho supply assets (what repay can free for this vault)
        (uint256 vSupplyShares,,) = IMorphoU(MORPHO).position(ELE77, YELE_K);
        (uint128 sa, uint128 ss,,,,) = IMorphoU(MORPHO).market(ELE77);
        uint256 vaultEleAssets = ss == 0 ? 0 : (vSupplyShares * uint256(sa)) / uint256(ss);
        uint256 flash = vaultEleAssets;
        if (flash > claim) flash = claim;
        // small haircut against interest/rounding
        if (flash > 2e6) flash -= 2e6;
        require(flash >= 1e6, "FLASH_DUST");

        console2.log("shares", shares);
        console2.log("claim", claim);
        console2.log("vaultEleAssets", vaultEleAssets);
        console2.log("flash", flash);
        console2.log("maxWithdrawBefore", IYeleU(YELE_K).maxWithdraw(HOT));
        console2.log("hotUsdcBefore", IERC20U(USDC).balanceOf(HOT));

        vm.startBroadcast(hotPk);
        CrownDebtRepayUnlock h = new CrownDebtRepayUnlock(HOT, YELE_K);
        console2.log("helper", address(h));
        IERC20U(YELE_K).approve(address(h), type(uint256).max);
        h.unlock(flash, HOT, HOT);
        vm.stopBroadcast();

        console2.log("hotUsdcAfter", IERC20U(USDC).balanceOf(HOT));
        console2.log("sharesLeft", IYeleU(YELE_K).balanceOf(HOT));
        console2.log("claimLeft", IYeleU(YELE_K).convertToAssets(IYeleU(YELE_K).balanceOf(HOT)));
        console2.log("vaultTA", IYeleU(YELE_K).totalAssets());
        console2.log("POT_UNLOCK_OK", uint256(1));
    }
}
