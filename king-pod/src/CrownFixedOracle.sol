// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Morpho Blue oracle — `price()` is loan-per-collateral base units scaled by 1e36.
/// @dev ELE 8dp / USDC 6dp at $1 → 1e34. At $1.50 → 1.5e34. Not 1.5e18.
contract CrownFixedOracle {
    address public owner;
    uint256 private _price;

    error NotOwner();

    event PriceSet(uint256 price);

    constructor(uint256 price_) {
        owner = msg.sender;
        _price = price_;
        emit PriceSet(price_);
    }

    function price() external view returns (uint256) {
        return _price;
    }

    function setPrice(uint256 price_) external {
        if (msg.sender != owner) revert NotOwner();
        _price = price_;
        emit PriceSet(price_);
    }

    function transferOwnership(address n) external {
        if (msg.sender != owner) revert NotOwner();
        require(n != address(0), "ZERO");
        owner = n;
    }
}
