// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkGateKRT {
    function isProven(address subject) external view returns (bool);
}

interface IBordersKRT {
    function bordersSecure() external view returns (bool);
}

/// @notice Build 3 — CrownKRT (KingCoin). Safe-only mint/burn. 18 decimals.
/// @dev Wired to live HotOracle50k + SovereignRailLLTV55. Not a claim on USDC.
contract CrownKRT is Ownable {
    string public constant name = "KingCoin";
    string public constant symbol = "KRT";
    uint8 public constant decimals = 18;

    IZkGateKRT public immutable zkGate;
    IBordersKRT public immutable attest;
    address public immutable king;
    address public immutable oracle; // HotOracle50k Build 2
    address public immutable sovereignRail; // SovereignRailLLTV55 Build 1

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    error Auth();
    error Zero();
    error NotProven();
    error Borders();

    modifier onlySafe() {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(
        address zkGate_,
        address attest_,
        address oracle_,
        address sovereignRail_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        require(
            zkGate_ != address(0) && attest_ != address(0) && oracle_ != address(0)
                && sovereignRail_ != address(0) && king_ != address(0),
            "ZERO"
        );
        zkGate = IZkGateKRT(zkGate_);
        attest = IBordersKRT(attest_);
        oracle = oracle_;
        sovereignRail = sovereignRail_;
        king = king_;
    }

    function mint(address to, uint256 amt) external onlySafe whenZk {
        if (to == address(0) || amt == 0) revert Zero();
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function burn(uint256 amt) external onlySafe whenZk {
        _burn(msg.sender, amt);
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
