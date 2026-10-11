// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice gUSD — second sovereign stable (18dp). Mint/burn King/HOT.
contract CrownGusd is Ownable {
    string public constant name = "Crown gUSD";
    string public constant symbol = "gUSD";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public minter;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event MinterSet(address indexed minter, bool ok);

    error Auth();
    error Zero();

    modifier onlyMinter() {
        if (!minter[msg.sender] && msg.sender != owner) revert Auth();
        _;
    }

    constructor(address owner_) Ownable(owner_) {
        minter[owner_] = true;
    }

    function setMinter(address m, bool ok) external onlyOwner {
        minter[m] = ok;
        emit MinterSet(m, ok);
    }

    function mint(address to, uint256 amt) external onlyMinter {
        if (to == address(0) || amt == 0) revert Zero();
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function burn(uint256 amt) external {
        uint256 bal = balanceOf[msg.sender];
        require(bal >= amt && amt > 0, "BAL");
        unchecked {
            balanceOf[msg.sender] = bal - amt;
            totalSupply -= amt;
        }
        emit Transfer(msg.sender, address(0), amt);
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
            unchecked {
                allowance[from][msg.sender] = a - amt;
            }
        }
        _transfer(from, to, amt);
        return true;
    }

    function _transfer(address from, address to, uint256 amt) internal {
        if (to == address(0)) revert Zero();
        uint256 bal = balanceOf[from];
        require(bal >= amt, "BAL");
        unchecked {
            balanceOf[from] = bal - amt;
            balanceOf[to] += amt;
        }
        emit Transfer(from, to, amt);
    }
}
