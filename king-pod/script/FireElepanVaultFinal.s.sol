// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoF {
    function submitTimelock(uint256) external;
    function acceptTimelock() external;
    function timelock() external view returns (uint256);
    function pendingTimelock() external view returns (uint256 newTimelock, uint64 validAt);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
    function isAllocator(address) external view returns (bool);
}

interface IPublicAllocatorF {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

interface IWETHF {
    function deposit() external payable;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Final MetaMorpho yELEPAN-WETH ops: 50% PA caps, dead deposit, harden timelock.
/// @dev KING_GO=1 FIRE_FINAL=1. Adapter-registry steps are Vault V2 — see FireElepanVaultV2.
contract FireElepanVaultFinal is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant VAULT = 0xfdD5a1d4823411809D6ac735991B3A015E5AaAb5;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    bytes32 constant MARKET_WETH = 0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 constant HALF_CAP = 10_000 ether;
    uint256 constant TL_5D = 5 days;
    uint256 constant DEAD_AMT = 1e9;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_FINAL", uint256(0)) == 1, "NEED FIRE_FINAL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMetaMorphoF mm = IMetaMorphoF(VAULT);
        require(mm.isAllocator(PA), "PA_NOT_ALLOCATOR");

        vm.startBroadcast(pk);

        // Flow caps 50% (cbBTC N/A — vault asset is WETH only)
        IPublicAllocatorF.FlowCapsConfig[] memory caps = new IPublicAllocatorF.FlowCapsConfig[](1);
        caps[0] = IPublicAllocatorF.FlowCapsConfig({
            id: MARKET_WETH, caps: IPublicAllocatorF.FlowCaps({maxIn: uint128(HALF_CAP), maxOut: uint128(HALF_CAP)})
        });
        IPublicAllocatorF(PA).setFlowCaps(VAULT, caps);

        if (mm.totalAssets() < DEAD_AMT) {
            if (IWETHF(WETH).balanceOf(HOT) < DEAD_AMT) {
                IWETHF(WETH).deposit{value: DEAD_AMT}();
            }
            IWETHF(WETH).approve(VAULT, DEAD_AMT);
            mm.deposit(DEAD_AMT, DEAD);
        }

        // Increasing timelock applies immediately on MetaMorpho
        if (mm.timelock() < TL_5D) {
            mm.submitTimelock(TL_5D);
        }

        vm.stopBroadcast();

        (uint128 maxIn, uint128 maxOut) = IPublicAllocatorF(PA).flowCaps(VAULT, MARKET_WETH);
        console2.log("maxIn", uint256(maxIn));
        console2.log("maxOut", uint256(maxOut));
        console2.log("totalAssets", mm.totalAssets());
        console2.log("timelock", mm.timelock());
    }
}
