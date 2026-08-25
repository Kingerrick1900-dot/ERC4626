// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IAggregatorPoR {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

/// @title CrownGoldUsd (gUSD)
/// @notice Brand layer: 1:1 wrap of kingdom eUSD as Gold USD. Gold PoR is primary narrative;
///         RSS/eUSD rails stay the execution physics underneath. No new oracle. No mint from thin air.
/// @dev wrap(eUSD) → gUSD; unwrap(gUSD) → eUSD. Peg story: $1 gUSD backed by kingdom gold PoR + eUSD float.
contract CrownGoldUsd is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    string public constant name = "Kingdom Gold USD";
    string public constant symbol = "gUSD";
    uint8 public constant decimals = 18;

    IERC20 public immutable eusd;
    IAggregatorPoR public goldPor;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Wrapped(address indexed from, address indexed to, uint256 amount);
    event Unwrapped(address indexed from, address indexed to, uint256 amount);
    event GoldPorSet(address indexed por);

    error BadAmt();
    error BadPor();

    constructor(address eusd_, address goldPor_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        if (goldPor_ != address(0)) goldPor = IAggregatorPoR(goldPor_);
    }

    function setGoldPor(address por) external onlyOwner {
        goldPor = IAggregatorPoR(por);
        emit GoldPorSet(por);
    }

    /// @notice Live gold PoR answer (USD 8dp typical) — primary collateral narrative.
    function goldBackingUsd() public view returns (uint256) {
        if (address(goldPor) == address(0)) return 0;
        (, int256 ans,,,) = goldPor.latestRoundData();
        if (ans <= 0) return 0;
        return uint256(ans);
    }

    /// @notice eUSD locked in this wrapper (= circulating gUSD).
    function eusdFloat() external view returns (uint256) {
        return eusd.balanceOf(address(this));
    }

    /// @notice Wrap eUSD → gUSD 1:1.
    function wrap(uint256 amt, address to) external nonReentrant returns (uint256) {
        if (amt == 0) revert BadAmt();
        if (to == address(0)) to = msg.sender;
        eusd.safeTransferFrom(msg.sender, address(this), amt);
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
        emit Wrapped(msg.sender, to, amt);
        return amt;
    }

    /// @notice Unwrap gUSD → eUSD 1:1.
    function unwrap(uint256 amt, address to) external nonReentrant returns (uint256) {
        if (amt == 0 || balanceOf[msg.sender] < amt) revert BadAmt();
        if (to == address(0)) to = msg.sender;
        balanceOf[msg.sender] -= amt;
        totalSupply -= amt;
        emit Transfer(msg.sender, address(0), amt);
        eusd.safeTransfer(to, amt);
        emit Unwrapped(msg.sender, to, amt);
        return amt;
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
