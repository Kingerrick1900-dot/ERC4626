// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, Ownable} from "./lib/Core.sol";

/// @notice KingCoin (KRT) — sovereign currency. Mint/burn Safe King (or HOT until Safe wired).
/// @dev Not a claim on USDC. Backed operationally by Kingdom RSS books. 18 decimals.
contract CrownKRT is Ownable {
    string public constant name = "KingCoin";
    string public constant symbol = "KRT";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public king; // Safe — sole mint/burn when set; owner bootstraps
    mapping(address => bool) public minter;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event KingSet(address indexed king);
    event MinterSet(address indexed minter, bool ok);

    error Auth();
    error Zero();

    modifier onlyKingOrOwner() {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    modifier onlyMinter() {
        if (!minter[msg.sender] && msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    constructor(address owner_, address king_) Ownable(owner_) {
        king = king_;
        minter[owner_] = true;
        if (king_ != address(0)) minter[king_] = true;
    }

    function setKing(address k) external onlyOwner {
        king = k;
        if (k != address(0)) minter[k] = true;
        emit KingSet(k);
    }

    function setMinter(address m, bool ok) external onlyKingOrOwner {
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
        _burn(msg.sender, amt);
    }

    function burnFrom(address from, uint256 amt) external onlyMinter {
        _burn(from, amt);
    }

    function _burn(address from, uint256 amt) internal {
        if (amt == 0) revert Zero();
        uint256 bal = balanceOf[from];
        require(bal >= amt, "BAL");
        unchecked {
            balanceOf[from] = bal - amt;
            totalSupply -= amt;
        }
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
