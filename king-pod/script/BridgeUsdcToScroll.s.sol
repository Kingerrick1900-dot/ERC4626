// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20B {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ITokenMessengerV2 {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external returns (uint64 nonce);
}

/// @notice Bridge USDC Base → Scroll via Circle CCTP V2.
/// @dev KING_GO=1 FIRE_BRIDGE=1 AMT=<raw 6dp> (default: all hot USDC above dust)
///      Scroll CCTP domain = 14. Mints to Scroll hot by default.
contract BridgeUsdcToScroll is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    uint32 constant SCROLL_DOMAIN = 14;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_BRIDGE", uint256(0)) == 1, "NEED FIRE_BRIDGE=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address mintTo = vm.envOr("MINT_TO", SCROLL_HOT);
        uint256 bal = IERC20B(USDC).balanceOf(HOT);
        uint256 dust = vm.envOr("KEEP_DUST", uint256(1_000)); // keep 0.001 USDC
        uint256 amt = vm.envOr("AMT", bal > dust ? bal - dust : uint256(0));
        require(amt >= 100_000, "MIN_0_10_USDC"); // 0.10 USDC floor
        require(bal >= amt, "HOT_USDC_SHORT");

        console2.log("bal", bal);
        console2.log("amt", amt);
        console2.log("mintTo", mintTo);
        console2.log("REPAY_SOURCE", "CCTP.mint(Scroll)");

        bytes32 mintRecipient = bytes32(uint256(uint160(mintTo)));
        uint256 maxFee = vm.envOr("MAX_FEE", uint256(0));
        uint32 minFinality = uint32(vm.envOr("MIN_FINALITY", uint256(2000)));

        vm.startBroadcast(pk);
        IERC20B(USDC).approve(TOKEN_MESSENGER, amt);
        // V2 may not ABI-return nonce cleanly on all messengers — ignore return.
        try ITokenMessengerV2(TOKEN_MESSENGER).depositForBurn(
            amt, SCROLL_DOMAIN, mintRecipient, USDC, bytes32(0), maxFee, minFinality
        ) returns (uint64 nonce) {
            console2.log("cctpNonce", uint256(nonce));
        } catch {
            ITokenMessengerV2(TOKEN_MESSENGER).depositForBurn(
                amt, SCROLL_DOMAIN, mintRecipient, USDC, bytes32(0), maxFee, minFinality
            );
            console2.log("cctpNonce", uint256(0));
        }
        vm.stopBroadcast();

        console2.log("BRIDGE_USDC_SCROLL_OK", uint256(1));
    }
}
