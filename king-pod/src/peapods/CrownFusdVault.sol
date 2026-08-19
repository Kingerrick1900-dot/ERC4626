// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer} from "../lib/Core.sol";

/// @notice Peapods fUSDC analogue — ERC4626-lite USDC vault.
/// @dev Share price counts cash + outstanding borrows (Fraxlend-style), so self-lend
///      can LP receipt shares then borrow the same USDC without collapsing share value.
contract CrownFusdVault {
    using SafeTransfer for IERC20;

    string public constant name = "Kingdom fUSDC";
    string public constant symbol = "fUSDC";
    uint8 public constant decimals = 18;

    IERC20 public immutable asset; // USDC 6dp
    address public immutable king;
    address public pair;

    uint256 public totalSupply;
    uint256 public cash; // USDC sitting in vault
    uint256 public totalBorrows; // USDC lent out
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    error OnlyPair();
    error OnlyKing();
    error Insolvent();

    constructor(address usdc_, address king_) {
        asset = IERC20(usdc_);
        king = king_;
    }

    function setPair(address pair_) external {
        if (msg.sender != king) revert OnlyKing();
        pair = pair_;
    }

    function totalAssets() public view returns (uint256) {
        return cash + totalBorrows;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 ta = totalAssets();
        if (totalSupply == 0 || ta == 0) return assets * 1e12;
        return (assets * totalSupply) / ta;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalSupply == 0) return shares / 1e12;
        return (shares * totalAssets()) / totalSupply;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        cash += assets;
        totalSupply += shares;
        balanceOf[receiver] += shares;
        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner_) external returns (uint256 assets) {
        if (msg.sender != owner_) {
            uint256 a = allowance[owner_][msg.sender];
            if (a != type(uint256).max) allowance[owner_][msg.sender] = a - shares;
        }
        assets = convertToAssets(shares);
        if (assets > cash) revert Insolvent(); // cannot redeem idle when util 100%
        balanceOf[owner_] -= shares;
        totalSupply -= shares;
        cash -= assets;
        asset.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
        emit Transfer(owner_, address(0), shares);
    }

    function pairBorrow(uint256 assets, address to) external {
        if (msg.sender != pair) revert OnlyPair();
        if (assets > cash) revert Insolvent();
        cash -= assets;
        totalBorrows += assets;
        asset.safeTransfer(to, assets);
    }

    function pairRepay(uint256 assets) external {
        if (msg.sender != pair) revert OnlyPair();
        asset.safeTransferFrom(msg.sender, address(this), assets);
        cash += assets;
        totalBorrows -= assets;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        emit Approval(msg.sender, spender, amt);
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        _transfer(msg.sender, to, amt);
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        _transfer(from, to, amt);
        return true;
    }

    function _transfer(address from, address to, uint256 amt) internal {
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
    }
}
