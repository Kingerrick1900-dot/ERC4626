// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer} from "../lib/Core.sol";

/// @notice Peapods pTKN analogue — 1:1 wrap of ELE into pELE (scaled to 18dp).
contract CrownPodWrap {
    using SafeTransfer for IERC20;

    string public constant name = "Kingdom pELE";
    string public constant symbol = "pELE";
    uint8 public constant decimals = 18;

    IERC20 public immutable asset; // ELE 8dp
    address public immutable king;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Wrap(address indexed user, uint256 eleIn, uint256 pOut);
    event Unwrap(address indexed user, uint256 pIn, uint256 eleOut);

    constructor(address ele_, address king_) {
        asset = IERC20(ele_);
        king = king_;
    }

    /// @dev ELE 8dp → pELE 18dp (× 1e10)
    function wrap(uint256 eleAmt) external returns (uint256 pOut) {
        asset.safeTransferFrom(msg.sender, address(this), eleAmt);
        pOut = eleAmt * 1e10;
        totalSupply += pOut;
        balanceOf[msg.sender] += pOut;
        emit Wrap(msg.sender, eleAmt, pOut);
        emit Transfer(address(0), msg.sender, pOut);
    }

    function unwrap(uint256 pAmt) external returns (uint256 eleOut) {
        balanceOf[msg.sender] -= pAmt;
        totalSupply -= pAmt;
        eleOut = pAmt / 1e10;
        asset.safeTransfer(msg.sender, eleOut);
        emit Unwrap(msg.sender, pAmt, eleOut);
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
