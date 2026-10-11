// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownOracle
/// @notice Morpho Blue IOracle — fixed price under sole King (HOT) control.
/// @dev Price = loan-token raw units per 1 collateral wei, scaled by 1e36.
///      For RSS (18) / USDC (6): Morpho price for $P per RSS = P * 1e24.
///      Example: $1,200 → 1200000000000000000000000000; $50,000 → 50000000000000000000000000000.
contract CrownOracle {
    address public owner;
    uint256 public priceValue;

    event PriceUpdated(uint256 price);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error ZeroPrice();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param initialOwner King's HOT — exclusive authority at deploy.
    /// @param initialPrice Morpho-scaled price (must be > 0).
    constructor(address initialOwner, uint256 initialPrice) {
        if (initialOwner == address(0)) revert ZeroAddress();
        if (initialPrice == 0) revert ZeroPrice();
        owner = initialOwner;
        priceValue = initialPrice;
        emit PriceUpdated(initialPrice);
    }

    /// @notice Morpho Blue oracle surface.
    function price() external view returns (uint256) {
        return priceValue;
    }

    /// @notice King sets the price — no timelock, no external gate.
    function setPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert ZeroPrice();
        priceValue = newPrice;
        emit PriceUpdated(newPrice);
    }

    /// @notice Transfer authority only by the current owner (King).
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
