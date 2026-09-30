// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @title CrownPendleSleeve
/// @notice Parking adapter for the ~$20M Pendle PT sleeve until a live PT market is wired.
/// @dev ERC4626-shaped deposit/redeem against USDC. Owner swaps into PT off this balance when named.
contract CrownPendleSleeve is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable assetToken;
    address public immutable tranche;
    uint256 public totalShares;
    mapping(address => uint256) public balanceOf;

    address public ptToken; // set when Pendle PT chosen
    string public label = "KE-Sov Pendle PT sleeve (parked USDC)";

    event Deposit(address indexed from, uint256 assets, uint256 shares);
    event Redeem(address indexed to, uint256 shares, uint256 assets);
    event PtSet(address pt);

    error Auth();
    error Bad();

    constructor(address usdc_, address tranche_, address owner_) Ownable(owner_) {
        assetToken = IERC20(usdc_);
        tranche = tranche_;
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    function setPt(address pt) external onlyOwner {
        ptToken = pt;
        emit PtSet(pt);
    }

    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (msg.sender != tranche && msg.sender != owner) revert Auth();
        if (assets == 0 || receiver == address(0)) revert Bad();
        assetToken.safeTransferFrom(msg.sender, address(this), assets);
        shares = assets; // 1:1 parked
        totalShares += shares;
        balanceOf[receiver] += shares;
        emit Deposit(msg.sender, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner_) external nonReentrant returns (uint256 assets) {
        if (msg.sender != tranche && msg.sender != owner && msg.sender != owner_) revert Auth();
        if (shares == 0 || balanceOf[owner_] < shares) revert Bad();
        balanceOf[owner_] -= shares;
        totalShares -= shares;
        assets = shares;
        assetToken.safeTransfer(receiver, assets);
        emit Redeem(receiver, shares, assets);
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }
}
