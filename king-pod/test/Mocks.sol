// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer} from "../src/lib/Core.sol";
import {IFlashLoanRecipient, IBalancerVault} from "../src/KingPod.sol";

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public immutable override decimals;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
    }

    function approve(address spender, uint256 amt) external override returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external override returns (bool) {
        require(balanceOf[msg.sender] >= amt, "BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external override returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amt, "ALLOW");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        require(balanceOf[from] >= amt, "BAL");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockBalancer is IBalancerVault {
    using SafeTransfer for IERC20;

    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external override {
        uint256[] memory fees = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            fees[i] = 0;
            tokens[i].safeTransfer(address(recipient), amounts[i]);
        }
        recipient.receiveFlashLoan(tokens, amounts, fees, userData);
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i].balanceOf(address(this)) >= amounts[i] + fees[i], "REPAY");
        }
    }
}
