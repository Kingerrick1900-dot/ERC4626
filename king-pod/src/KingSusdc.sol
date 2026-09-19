// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice ERC4626-like USDC receipt for Option A (sUSDC).
contract KingSusdc is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable asset; // USDC
    string public constant name = "King sUSDC";
    string public constant symbol = "sUSDC";
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Deposit(address indexed from, address indexed to, uint256 assets, uint256 shares);
    event Withdraw(address indexed from, address indexed to, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(address usdc, address owner_) Ownable(owner_) {
        asset = IERC20(usdc);
        decimals = IERC20(usdc).decimals();
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        uint256 ta = totalAssets();
        if (supply == 0 || ta == 0) return assets;
        return (assets * supply) / ta;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return shares;
        return (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares > 0, "SHARES");
        asset.safeTransferFrom(msg.sender, address(this), assets);
        balanceOf[receiver] += shares;
        totalSupply += shares;
        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner_) external nonReentrant returns (uint256 assets) {
        if (msg.sender != owner_) {
            uint256 allowed = allowance[owner_][msg.sender];
            require(allowed >= shares, "ALLOW");
            if (allowed != type(uint256).max) allowance[owner_][msg.sender] = allowed - shares;
        }
        assets = convertToAssets(shares);
        require(assets > 0, "ASSETS");
        balanceOf[owner_] -= shares;
        totalSupply -= shares;
        asset.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, assets, shares);
        emit Transfer(owner_, address(0), shares);
    }

    /// @dev Pull USDC out for borrows (only KingMoneyMarket).
    function pullAssets(address to, uint256 assets) external onlyOwner {
        asset.safeTransfer(to, assets);
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        emit Transfer(msg.sender, to, amt);
        return true;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        emit Approval(msg.sender, spender, amt);
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amt, "ALLOW");
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amt;
        require(balanceOf[from] >= amt, "BAL");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
        return true;
    }
}
