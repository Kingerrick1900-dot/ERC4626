// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKarPublicAllocator {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;

    function fee(address vault) external view returns (uint256);

    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);

    function setAdmin(address vault, address newAdmin) external;

    function setFee(address vault, uint256 newFee) external;

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;

    function admin(address vault) external view returns (address);
}
