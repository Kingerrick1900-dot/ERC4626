// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice King-stable (kUSD) — 6 decimals, USDC twin. Only CDP may mint/burn.
contract CrownKusd is Ownable {
    string public constant name = "Kingdom USD";
    string public constant symbol = "kUSD";
    uint8 public constant decimals = 6;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public minter;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MinterSet(address indexed minter);

    error NotMinter();
    error BadAmt();

    constructor(address owner_) Ownable(owner_) {}

    function setMinter(address m) external onlyOwner {
        minter = m;
        emit MinterSet(m);
    }

    function mint(address to, uint256 amt) external {
        if (msg.sender != minter) revert NotMinter();
        if (amt == 0) revert BadAmt();
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function burn(address from, uint256 amt) external {
        if (msg.sender != minter) revert NotMinter();
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
        _transfer(msg.sender, to, amt);
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            if (a < amt) revert BadAmt();
            allowance[from][msg.sender] = a - amt;
        }
        _transfer(from, to, amt);
        return true;
    }

    function _transfer(address from, address to, uint256 amt) internal {
        if (to == address(0) || balanceOf[from] < amt) revert BadAmt();
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
    }
}
