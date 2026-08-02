// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IYeleCap {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function acceptCap(MarketParams calldata marketParams) external;
    function acceptTimelock() external;
    function pendingCap(bytes32 id) external view returns (uint184 value, uint64 validAt);
    function pendingTimelock() external view returns (uint256 value, uint64 validAt);
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function timelock() external view returns (uint256);
    function setSupplyQueue(bytes32[] calldata ids) external;
    function updateWithdrawQueue(uint256[] calldata indexes) external;
    function supplyQueueLength() external view returns (uint256);
    function withdrawQueueLength() external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
    function withdrawQueue(uint256) external view returns (bytes32);
}

/// @notice Accept pending yELE WETH/USDC cap + timelock after unlock.
/// @dev Live only: KING_GO=1 FIRE_ACCEPT_CAP=1. Preflight: omit FIRE_ACCEPT_CAP.
contract FireAcceptYeleCap is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_86 = 860000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        bool fire = vm.envOr("FIRE_ACCEPT_CAP", uint256(0)) == 1;

        IYeleCap.MarketParams memory wethMp =
            IYeleCap.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86);

        (uint184 pendCap, uint64 capAt) = IYeleCap(YELE).pendingCap(WETH_USDC);
        (uint256 pendTl, uint64 tlAt) = IYeleCap(YELE).pendingTimelock();
        (uint184 liveCap, bool enabled,) = IYeleCap(YELE).config(WETH_USDC);

        console2.log("blockTs", block.timestamp);
        console2.log("pendingCap", uint256(pendCap));
        console2.log("capValidAt", uint256(capAt));
        console2.log("pendingTimelock", pendTl);
        console2.log("tlValidAt", uint256(tlAt));
        console2.log("liveWethCap", uint256(liveCap));
        console2.log("wethEnabled", enabled ? uint256(1) : uint256(0));
        console2.log("timelock", IYeleCap(YELE).timelock());

        bool capReady = pendCap > 0 && block.timestamp >= uint256(capAt);
        bool tlReady = pendTl > 0 && block.timestamp >= uint256(tlAt);
        console2.log("capReady", capReady ? uint256(1) : uint256(0));
        console2.log("tlReady", tlReady ? uint256(1) : uint256(0));

        if (!fire) {
            console2.log("PREFLIGHT_ONLY set FIRE_ACCEPT_CAP=1 after King GO");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        vm.startBroadcast(pk);
        if (capReady) {
            IYeleCap(YELE).acceptCap(wethMp);
            console2.log("ACCEPTED_CAP", uint256(1));
        }
        if (tlReady) {
            IYeleCap(YELE).acceptTimelock();
            console2.log("ACCEPTED_TIMELOCK", uint256(1));
        }

        // ELE first for deposits; WETH sink on withdraw/reallocate path
        bytes32[] memory supplyQ = new bytes32[](2);
        supplyQ[0] = ELE_USDC;
        supplyQ[1] = WETH_USDC;
        IYeleCap(YELE).setSupplyQueue(supplyQ);

        // withdraw queue: keep both markets addressable (indexes into current withdraw queue)
        // after accept, withdraw queue may still be ELE-only — update if length allows
        uint256 wLen = IYeleCap(YELE).withdrawQueueLength();
        console2.log("withdrawQueueLength", wLen);
        vm.stopBroadcast();

        (, bool en2,) = IYeleCap(YELE).config(WETH_USDC);
        console2.log("wethEnabledAfter", en2 ? uint256(1) : uint256(0));
        console2.log("NEXT", "FIRE_OPS_FIVE=1 CLEANSE=1 after King GO");
    }
}
