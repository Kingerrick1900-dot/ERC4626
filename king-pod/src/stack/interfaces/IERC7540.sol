// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice ERC-7540 async vault surface (request / claimable / claim).
interface IERC7540Redeem {
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );
    event RedeemClaimable(uint256 indexed requestId, uint256 assets, uint256 claimableOut);
    event RedeemClaimed(uint256 indexed requestId, address indexed receiver, uint256 outAmt);

    function requestRedeem(uint256 assets, address controller, address owner) external returns (uint256 requestId);
    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 assets);
    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 assets);
    function claimRedeem(uint256 requestId, address receiver) external returns (uint256 outAmt);
    function isOperator(address controller, address operator) external view returns (bool);
    function setOperator(address operator, bool approved) external returns (bool);
}

interface IERC20MetadataLite {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
