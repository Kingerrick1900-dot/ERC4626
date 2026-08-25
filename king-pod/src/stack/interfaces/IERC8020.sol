// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice ERC-8020 — Kingdom synchronous multi-chain redeem (no async queue).
/// @dev Successor doctrine to ERC-7540 requestRedeem. Same-tx redeem when PSM/liquidity allows.
interface IERC8020 {
    function redeemSync(uint256 assets, address receiver, address owner) external returns (uint256 usdcOut);
    function previewRedeemSync(uint256 assets) external view returns (uint256 usdcOut);
    function maxRedeemSync(address owner) external view returns (uint256);
}
