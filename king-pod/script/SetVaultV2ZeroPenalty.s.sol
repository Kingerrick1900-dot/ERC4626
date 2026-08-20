// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IVaultV2Pen {
    function curator() external view returns (address);
    function setForceDeallocatePenalty(address adapter, uint256 newPenalty) external;
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
}

/// @notice Set Vault V2 forceDeallocate penalty to 0% — institutional exit, suppliers not trapped.
/// @dev KING_OK=1. Curator = hot. Live vault from VAULT-V2-LIVE.md.
///      Penalty 0 = gas-only exit cost (King plan). Fork-proved path already exists at 1%; this softens.
contract SetVaultV2ZeroPenalty is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;

    error NOT_HOT();
    error NO_GO();
    error NOT_CURATOR();

    function run() external {
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();
        if (IVaultV2Pen(VAULT).curator() != HOT) revert NOT_CURATOR();

        uint256 before = IVaultV2Pen(VAULT).forceDeallocatePenalty(ADAPTER);
        console2.log("penaltyBefore", before);

        vm.startBroadcast(pk);
        IVaultV2Pen(VAULT).setForceDeallocatePenalty(ADAPTER, 0);
        vm.stopBroadcast();

        uint256 after_ = IVaultV2Pen(VAULT).forceDeallocatePenalty(ADAPTER);
        console2.log("penaltyAfter", after_);
        console2.log("ZERO_PENALTY_OK", after_ == 0 ? uint256(1) : uint256(0));
    }
}
