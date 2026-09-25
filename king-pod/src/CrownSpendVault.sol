// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @title CrownSpendVault
/// @notice On-chain spend policy for CrownKingAgent — per-tx / daily caps, target allowlist, pause.
/// @dev Aave-better: unsigned intent still needs this vault to move value. Caps are contract law.
contract CrownSpendVault is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    address public king;
    address public agent;
    bool public paused;

    uint256 public perTxLimit; // native wei or ERC20 raw — set per token via tokenLimits
    uint256 public dailyLimit;
    uint256 public dayStart;
    uint256 public spentToday;

    mapping(address => bool) public allowedTarget;
    mapping(address => uint256) public tokenPerTx; // 0 = use perTxLimit
    mapping(address => uint256) public tokenDaily; // 0 = use dailyLimit
    mapping(address => uint256) public tokenSpentToday;

    event AgentSet(address agent);
    event KingSet(address king);
    event Paused(bool on);
    event TargetAllowed(address target, bool on);
    event LimitsSet(uint256 perTx, uint256 daily);
    event TokenLimitsSet(address token, uint256 perTx, uint256 daily);
    event Executed(address indexed target, address indexed token, uint256 amount, bytes4 sel);

    error KingOnly();
    error AgentOnly();
    error PausedErr();
    error TargetDenied();
    error CapExceeded();
    error CallFail();
    error BadAmt();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(address king_, address owner_) Ownable(owner_) {
        require(king_ != address(0), "ZERO");
        king = king_;
        dayStart = block.timestamp;
        // defaults: tight until King raises
        perTxLimit = 1_000_000e18; // 1M eUSD-scale
        dailyLimit = 10_000_000e18;
    }

    function setAgent(address agent_) external onlyKing {
        agent = agent_;
        emit AgentSet(agent_);
    }

    function setKing(address king_) external onlyOwner {
        require(king_ != address(0), "ZERO");
        king = king_;
        emit KingSet(king_);
    }

    function setPaused(bool on) external onlyKing {
        paused = on;
        emit Paused(on);
    }

    function setLimits(uint256 perTx, uint256 daily) external onlyKing {
        perTxLimit = perTx;
        dailyLimit = daily;
        emit LimitsSet(perTx, daily);
    }

    function setTokenLimits(address token, uint256 perTx, uint256 daily) external onlyKing {
        tokenPerTx[token] = perTx;
        tokenDaily[token] = daily;
        emit TokenLimitsSet(token, perTx, daily);
    }

    function setTarget(address target, bool on) external onlyKing {
        allowedTarget[target] = on;
        emit TargetAllowed(target, on);
    }

    function _rollDay() internal {
        if (block.timestamp >= dayStart + 1 days) {
            dayStart = block.timestamp;
            spentToday = 0;
        }
    }

    /// @notice Agent executes calldata against allowlisted target; optional ERC20 pull counted against caps.
    function execute(address target, address token, uint256 amount, bytes calldata data)
        external
        nonReentrant
        returns (bytes memory ret)
    {
        if (msg.sender != agent && msg.sender != king && msg.sender != owner) revert AgentOnly();
        if (paused) revert PausedErr();
        if (!allowedTarget[target]) revert TargetDenied();

        _rollDay();
        uint256 ptx = token == address(0) ? perTxLimit : (tokenPerTx[token] == 0 ? perTxLimit : tokenPerTx[token]);
        uint256 day = token == address(0) ? dailyLimit : (tokenDaily[token] == 0 ? dailyLimit : tokenDaily[token]);

        if (amount > 0) {
            if (amount > ptx) revert CapExceeded();
            if (token == address(0)) {
                if (spentToday + amount > day) revert CapExceeded();
                spentToday += amount;
            } else {
                if (tokenSpentToday[token] + amount > day) revert CapExceeded();
                // reset token day with global day roll already done — simple shared day window
                if (block.timestamp >= dayStart + 1 days) tokenSpentToday[token] = 0;
                tokenSpentToday[token] += amount;
                IERC20(token).safeApprove(target, 0);
                IERC20(token).safeApprove(target, amount);
            }
        }

        (bool ok, bytes memory dataOut) = target.call{value: token == address(0) ? amount : 0}(data);
        if (!ok) {
            if (dataOut.length > 0) {
                assembly {
                    revert(add(dataOut, 0x20), mload(dataOut))
                }
            }
            revert CallFail();
        }
        bytes4 sel;
        if (data.length >= 4) {
            assembly {
                sel := mload(add(data.offset, 0))
            }
        }
        emit Executed(target, token, amount, sel);
        return dataOut;
    }

    function sweep(address token, uint256 amt) external onlyKing {
        if (token == address(0)) {
            uint256 bal = address(this).balance;
            uint256 send = amt == 0 ? bal : amt;
            (bool ok,) = king.call{value: send}("");
            require(ok, "ETH");
        } else {
            IERC20 t = IERC20(token);
            t.safeTransfer(king, amt == 0 ? t.balanceOf(address(this)) : amt);
        }
    }

    receive() external payable {}
}
