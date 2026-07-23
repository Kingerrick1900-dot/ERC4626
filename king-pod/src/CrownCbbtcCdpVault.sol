// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrownAssetCdpVault} from "./CrownAssetCdpVault.sol";

/// @notice Isolated King-only cbBTC CDP → mint eUSD. Oracle = UniV3 cbBTC/USDC TWAP (Morpho scale).
contract CrownCbbtcCdpVault is CrownAssetCdpVault {
    address public constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    constructor(
        address eusd_,
        address oracle_,
        address zkGate_,
        address king_,
        address feeRecipient_,
        uint256 liquidationRatio_,
        uint256 safetyFloor_,
        uint256 stabilityFeeBpsYear_
    )
        CrownAssetCdpVault(
            CBTC, eusd_, oracle_, zkGate_, king_, feeRecipient_, liquidationRatio_, safetyFloor_, stabilityFeeBpsYear_
        )
    {}
}
