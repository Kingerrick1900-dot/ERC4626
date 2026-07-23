// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrownAssetCdpVault} from "./CrownAssetCdpVault.sol";

/// @notice Isolated King-only WETH CDP → mint eUSD. Oracle = UniV3 WETH/USDC TWAP (Morpho scale).
contract CrownWethCdpVault is CrownAssetCdpVault {
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    constructor(
        address eusd_,
        address oracle_,
        address zkGate_,
        address king_,
        address feeRecipient_,
        address treasury_,
        uint256 liquidationRatio_,
        uint256 safetyFloor_,
        uint256 stabilityFeeBpsYear_
    )
        CrownAssetCdpVault(
            WETH,
            eusd_,
            oracle_,
            zkGate_,
            king_,
            feeRecipient_,
            treasury_,
            liquidationRatio_,
            safetyFloor_,
            stabilityFeeBpsYear_
        )
    {}
}
