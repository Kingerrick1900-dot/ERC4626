// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20C {
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

/// @notice Cross-chain USDC: Base -> Ethereum via Circle CCTP V2.
/// @dev KING_OK=1 KING_GO=1 FIRE_CCTP=1 AMT=...
///      Burns USDC on Base, mints to mintRecipient on Ethereum (domain 0).
contract FireCctpBridgeUsdc is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    uint32 constant ETH_DOMAIN = 0;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_KING_GO");
        require(vm.envOr("FIRE_CCTP", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        // Default mint to Landing on ETH (same address works as EOA on both)
        address mintTo = vm.envOr("MINT_TO", LANDING);
        uint256 amt = vm.envUint("AMT");
        require(amt >= 1_000_000, "MIN_1_USDC"); // no dust bridge

        uint256 bal = IERC20C(USDC).balanceOf(HOT);
        // Prefer bridging from hot; if FROM_LANDING=1 King must move first
        require(bal >= amt, "HOT_USDC_SHORT");

        bytes32 mintRecipient = bytes32(uint256(uint160(mintTo)));
        bytes32 destCaller = bytes32(0);
        uint256 maxFee = vm.envOr("MAX_FEE", uint256(0));
        uint32 minFinality = uint32(vm.envOr("MIN_FINALITY", uint256(2000)));

        vm.startBroadcast(pk);
        IERC20C(USDC).approve(TOKEN_MESSENGER, amt);
        uint64 nonce = ITokenMessengerV2(TOKEN_MESSENGER).depositForBurn(
            amt, ETH_DOMAIN, mintRecipient, USDC, destCaller, maxFee, minFinality
        );
        vm.stopBroadcast();

        console2.log("bridgedAmt", amt);
        console2.log("mintTo", mintTo);
        console2.log("cctpNonce", uint256(nonce));
        console2.log("CCTP_OK", uint256(1));
    }
}
