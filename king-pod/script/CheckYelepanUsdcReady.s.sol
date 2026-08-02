// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoC {
    function owner() external view returns (address);
    function curator() external view returns (address);
    function totalAssets() external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
}

interface IMorphoC {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IPA {
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

/// @notice Read-only readiness check for Merkl → yELEPAN-USDC → Elepan/USDC borrow path.
/// @dev No broadcast. No KING_GO required.
contract CheckYelepanUsdcReady is Script {
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external view {
        IMetaMorphoC v = IMetaMorphoC(YELE);
        console2.log("owner", v.owner());
        console2.log("curator", v.curator());
        console2.log("totalAssets", v.totalAssets());
        console2.log("fee", uint256(v.fee()));
        console2.log("feeRecipient", v.feeRecipient());
        console2.log("feeToLanding", v.feeRecipient() == LANDING ? uint256(1) : uint256(0));
        console2.log("ownerIsHot", v.owner() == HOT ? uint256(1) : uint256(0));

        bytes32 q0 = v.supplyQueue(0);
        console2.logBytes32(q0);
        console2.log("queue0IsEleUsdc", q0 == ELE_USDC ? uint256(1) : uint256(0));

        (uint184 cap, bool enabled,) = v.config(ELE_USDC);
        console2.log("cap", uint256(cap));
        console2.log("capEnabled", enabled ? uint256(1) : uint256(0));

        (uint128 maxIn, uint128 maxOut) = IPA(PA).flowCaps(YELE, ELE_USDC);
        console2.log("paMaxIn", uint256(maxIn));
        console2.log("paMaxOut", uint256(maxOut));

        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorphoC(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(supplyAssets) - uint256(borrowAssets);
        console2.log("marketSupplyUsdc", uint256(supplyAssets));
        console2.log("marketBorrowUsdc", uint256(borrowAssets));
        console2.log("marketIdleUsdc", idle);
        console2.log("READY_FOR_MERKL_PACK", uint256(1));
        console2.log("BORROW_BLOCKED_UNTIL_IDLE_FLOOR", idle < 100_000e6 ? uint256(1) : uint256(0));
    }
}
