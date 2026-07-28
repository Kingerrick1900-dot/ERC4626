// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer} from "../lib/Core.sol";
import {CrownFusdVault} from "./CrownFusdVault.sol";

interface IUniV2PairMin {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function totalSupply() external view returns (uint256);
}

/// @notice Peapods LVF lending analogue — borrow USDC from fUSDC vault against pELE/fUSDC LP.
contract CrownPeapodsPair {
    using SafeTransfer for IERC20;

    CrownFusdVault public immutable vault;
    IERC20 public immutable lpToken;
    address public immutable king;

    /// @dev Peapods: LP holds pELE + fUSDC (~2× fUSDC-leg at soft $1). 50% LTV on full LP ≈ 100% of deposited USDC.
    uint256 public constant LTV_BPS = 5000;

    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;

    event SupplyCollateral(address indexed user, uint256 lpAmt);
    event Borrow(address indexed user, uint256 usdcAmt);
    event Repay(address indexed user, uint256 usdcAmt);

    error Ltv();

    constructor(address vault_, address lp_, address king_) {
        vault = CrownFusdVault(vault_);
        lpToken = IERC20(lp_);
        king = king_;
    }

    function fusdcAssetsInLp(uint256 lpAmt) public view returns (uint256) {
        IUniV2PairMin p = IUniV2PairMin(address(lpToken));
        (uint112 r0, uint112 r1,) = p.getReserves();
        uint256 ts = p.totalSupply();
        if (ts == 0 || lpAmt == 0) return 0;
        uint256 fusdcRes = p.token0() == address(vault) ? uint256(r0) : uint256(r1);
        uint256 fusdcShares = (lpAmt * fusdcRes) / ts;
        return vault.convertToAssets(fusdcShares);
    }

    function maxBorrow(address user) public view returns (uint256) {
        // Full LP value ≈ 2 × fUSDC leg at soft $1 ELE.
        uint256 lpUsd = fusdcAssetsInLp(collateral[user]) * 2;
        return (lpUsd * LTV_BPS) / 10_000;
    }

    function supplyCollateral(uint256 lpAmt, address onBehalf) external {
        lpToken.safeTransferFrom(msg.sender, address(this), lpAmt);
        collateral[onBehalf] += lpAmt;
        emit SupplyCollateral(onBehalf, lpAmt);
    }

    function borrow(uint256 usdcAmt, address onBehalf, address receiver) external {
        debt[onBehalf] += usdcAmt;
        if (debt[onBehalf] > maxBorrow(onBehalf)) revert Ltv();
        vault.pairBorrow(usdcAmt, receiver);
        emit Borrow(onBehalf, usdcAmt);
    }

    function repay(uint256 usdcAmt, address onBehalf) external {
        IERC20 usdc = vault.asset();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        usdc.safeApprove(address(vault), usdcAmt);
        vault.pairRepay(usdcAmt);
        debt[onBehalf] -= usdcAmt;
        emit Repay(onBehalf, usdcAmt);
    }
}
