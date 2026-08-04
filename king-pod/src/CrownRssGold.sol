// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice RSS gold receipt (kRSSG) — Elepan kXAU fork for RSS rail. 8 decimals, Morpho-ready.
/// @dev Mint/burn only via authorized wrapper (CrownRssGoldWrap). Not PAXG.
contract CrownRssGold {
    string public constant name = "Kingdom RSS Gold";
    string public constant symbol = "kRSSG";
    uint8 public constant decimals = 8;

    address public owner;
    address public minter; // CrownRssGoldWrap
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    error NotOwner();
    error NotMinter();
    error BadAmt();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed prev, address indexed next);
    event MinterSet(address indexed minter);

    constructor(address owner_) {
        require(owner_ != address(0), "ZERO");
        owner = owner_;
    }

    function setMinter(address minter_) external {
        if (msg.sender != owner) revert NotOwner();
        minter = minter_;
        emit MinterSet(minter_);
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
        if (msg.sender != minter) revert NotMinter();
        if (amount == 0 || to == address(0)) revert BadAmt();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        if (msg.sender != minter) revert NotMinter();
        uint256 bal = balanceOf[from];
        if (amount == 0 || bal < amount) revert BadAmt();
        unchecked {
            balanceOf[from] = bal - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
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
