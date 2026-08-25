// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Morpho Blue borrow-capacity reads (collateral × oracle × LLTV − debt).
interface IMorphoCap {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IOracleCap {
    function price() external view returns (uint256);
}

/// @title CrownBorrowCapacity
/// @notice Capacity-backed FX gate: max additional loan-token borrow vs posted Morpho collateral.
/// @dev Loan units = market loan token decimals (USDC=6dp). Not wallet inventory.
library CrownBorrowCapacity {
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;
    uint256 internal constant WAD = 1e18;

    /// @notice Additional borrowable loan assets for `user` on `marketId` (0 if underwater / empty).
    function borrowCapacity(address morpho, bytes32 marketId, address user) internal view returns (uint256) {
        (,, address oracle,, uint256 lltv) = IMorphoCap(morpho).idToMarketParams(marketId);
        if (oracle == address(0) || lltv == 0) return 0;

        (, uint128 borrowShares, uint128 collateral) = IMorphoCap(morpho).position(marketId, user);
        if (collateral == 0) return 0;

        uint256 price = IOracleCap(oracle).price();
        // collateralValue in loan-token base units
        uint256 collValue = (uint256(collateral) * price) / ORACLE_PRICE_SCALE;
        uint256 maxBorrow = (collValue * lltv) / WAD;

        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = IMorphoCap(morpho).market(marketId);
        uint256 debt;
        if (borrowShares > 0 && totalBorrowShares > 0) {
            debt = (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1)
                / uint256(totalBorrowShares);
        }
        return maxBorrow > debt ? maxBorrow - debt : 0;
    }
}
