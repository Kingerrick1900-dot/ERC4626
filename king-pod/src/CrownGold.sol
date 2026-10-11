// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Kingdom gold receipt (kXAU) — 8 decimals, Morpho-ready collateral.
/// @dev 1 full unit = one troy-oz claim unit at the market oracle. Oracle is set separately
///      (kingdom $10 Morpho lane uses CrownFixedOracle @ 1e35). Not a PAXG wrap.
contract CrownGold {
    string public constant name = "Kingdom Gold";
    string public constant symbol = "kXAU";
    uint8 public constant decimals = 8;

    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    error NotOwner();
    error BadAmt();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed prev, address indexed next);

    constructor(address owner_) {
        require(owner_ != address(0), "ZERO");
        owner = owner_;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            if (a < amount) revert BadAmt();
            unchecked {
                allowance[from][msg.sender] = a - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        if (amount == 0 || to == address(0)) revert BadAmt();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external {
        uint256 bal = balanceOf[msg.sender];
        if (amount == 0 || bal < amount) revert BadAmt();
        unchecked {
            balanceOf[msg.sender] = bal - amount;
            totalSupply -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
    }

    function transferOwnership(address next) external {
        if (msg.sender != owner) revert NotOwner();
        if (next == address(0)) revert BadAmt();
        emit OwnershipTransferred(owner, next);
        owner = next;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0) || amount == 0) revert BadAmt();
        uint256 bal = balanceOf[from];
        if (bal < amount) revert BadAmt();
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
