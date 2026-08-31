// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Shared safe-draw constants for 1B Mansa Lite / 50% LLTV.
library CrownPrimeSafeParams {
    /// @dev 1B eUSD @ paper mark = $22M (USDC 6dp).
    uint256 internal constant PAPER_USD6 = 22_000_000e6;
    /// @dev $0.022 per eUSD (8dp) so 1e9 * 1e18 * 2.2e6 / 1e20 = 22e12.
    uint256 internal constant PAPER_FLOAT_USD8 = 2.2e6;
    /// @dev 50% LLTV → max debt = $11M on $22M paper.
    uint256 internal constant LLTV_50 = 50e16;
    uint256 internal constant MAX_DEBT_USD6 = 11_000_000e6;
    /// @dev One-shot emergency draw (bypasses armed; still needs cash + capacity).
    uint256 internal constant EMERGENCY_CAP_USD6 = 2_000_000e6;
    uint256 internal constant MINT_1B = 1_000_000_000e18;
    uint256 internal constant SPLIT_PSM = 400_000_000e18;
    uint256 internal constant SPLIT_FILL = 300_000_000e18;
    uint256 internal constant SPLIT_CREDIT = 200_000_000e18;
    uint256 internal constant SPLIT_PROMO = 100_000_000e18;
}
