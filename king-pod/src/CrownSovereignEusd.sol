// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice Kingdom eUSD on expansion chains (Polygon) — minter-gated sovereign mint.
contract CrownSovereignEusd is Ownable {
    string public constant name = "Crown eUSD";
    string public constant symbol = "eUSD";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isMinter;

    event Transfer(address indexed from, address indexed to, uint256 amt);
    event Approval(address indexed owner, address indexed spender, uint256 amt);
    event MinterSet(address indexed minter, bool on);

    error NotMinter();

    constructor(address owner_) Ownable(owner_) {
        isMinter[owner_] = true;
    }

    function setMinter(address m, bool on) external onlyOwner {
        isMinter[m] = on;
        emit MinterSet(m, on);
    }

    function mint(address to, uint256 amt) external {
        if (!isMinter[msg.sender]) revert NotMinter();
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function burn(uint256 amt) external {
        _burn(msg.sender, amt);
    }

    function burnFrom(address from, uint256 amt) external {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            require(a >= amt, "ALLOW");
            allowance[from][msg.sender] = a - amt;
        }
        _burn(from, amt);
    }

    function _burn(address from, uint256 amt) internal {
        require(balanceOf[from] >= amt, "BAL");
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
            require(a >= amt, "ALLOW");
            allowance[from][msg.sender] = a - amt;
        }
        _transfer(from, to, amt);
        return true;
    }

    function _transfer(address from, address to, uint256 amt) internal {
        require(balanceOf[from] >= amt, "BAL");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
    }
}
