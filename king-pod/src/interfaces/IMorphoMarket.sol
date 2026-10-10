// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMorphoMarket {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
}
