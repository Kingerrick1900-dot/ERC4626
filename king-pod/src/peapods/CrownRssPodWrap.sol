// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer} from "../lib/Core.sol";

/// @notice Peapods pTKN analogue — 1:1 wrap of RSS (18dp) into pRSS (18dp).
contract CrownRssPodWrap {
    using SafeTransfer for IERC20;

    string public constant name = "Kingdom pRSS";
    string public constant symbol = "pRSS";
    uint8 public constant decimals = 18;

    IERC20 public immutable asset; // RSS 18dp
    address public immutable king;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Wrap(address indexed user, uint256 rssIn, uint256 pOut);
    event Unwrap(address indexed user, uint256 pIn, uint256 rssOut);

    constructor(address rss_, address king_) {
        asset = IERC20(rss_);
        king = king_;
    }

    function wrap(uint256 rssAmt) external returns (uint256 pOut) {
        asset.safeTransferFrom(msg.sender, address(this), rssAmt);
        pOut = rssAmt;
        totalSupply += pOut;
        balanceOf[msg.sender] += pOut;
        emit Wrap(msg.sender, rssAmt, pOut);
        emit Transfer(address(0), msg.sender, pOut);
    }

    function unwrap(uint256 pAmt) external returns (uint256 rssOut) {
        balanceOf[msg.sender] -= pAmt;
        totalSupply -= pAmt;
        rssOut = pAmt;
        asset.safeTransfer(msg.sender, rssOut);
        emit Unwrap(msg.sender, pAmt, rssOut);
        emit Transfer(msg.sender, address(0), pAmt);
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
