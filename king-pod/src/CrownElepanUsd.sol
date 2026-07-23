// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice Kingdom native stablecoin — multi-minter for isolated CDP vaults.
/// @dev Soft $1 unit of account. 18 decimals. No public mint.
contract CrownElepanUsd is Ownable {
    string public constant name = "Kingdom Elepan USD";
    string public constant symbol = "eUSD";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isMinter;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event MinterSet(address indexed minter, bool allowed);

    error OnlyMinter();
    error BadAmt();

    constructor(address owner_) Ownable(owner_) {}

    function setMinter(address m, bool allowed) external onlyOwner {
        require(m != address(0), "ZERO");
        isMinter[m] = allowed;
        emit MinterSet(m, allowed);
    }

    function mint(address to, uint256 amt) external {
        if (!isMinter[msg.sender]) revert OnlyMinter();
        if (amt == 0) revert BadAmt();
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function burn(address from, uint256 amt) external {
        if (!isMinter[msg.sender]) revert OnlyMinter();
        if (amt == 0 || balanceOf[from] < amt) revert BadAmt();
        balanceOf[from] -= amt;
        totalSupply -= amt;
        emit Transfer(from, address(0), amt);
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        emit Approval(msg.sender, spender, amt);
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        return _transfer(msg.sender, to, amt);
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            if (a < amt) revert BadAmt();
            allowance[from][msg.sender] = a - amt;
        }
        return _transfer(from, to, amt);
    }

    function _transfer(address from, address to, uint256 amt) internal returns (bool) {
        if (to == address(0) || balanceOf[from] < amt) revert BadAmt();
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
        return true;
    }
}
