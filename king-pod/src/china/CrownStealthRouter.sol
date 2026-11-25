// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IHuntRouter {
    function hunt(
        address token,
        uint256 assets,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        uint256 tipErc20
    ) external payable;
}

interface IBorders {
    function bordersSecure() external view returns (bool);
}

/// @title CrownStealthRouter
/// @notice ZK-gated multi-asset hunt front — intent commit hash, then flash exec, sweep HOT.
/// @dev Not a private mempool. Strategy blinding via commit-reveal; HuntRouter does Morpho flash.
contract CrownStealthRouter is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IHuntRouter public immutable huntRouter;
    address public immutable hot;
    address public attest;
    mapping(address => bool) public bot;
    mapping(bytes32 => bool) public committed;
    mapping(bytes32 => bool) public consumed;

    IERC20 public immutable weth;
    IERC20 public immutable cbbtc;
    IERC20 public immutable usdc;

    event BotSet(address indexed bot, bool ok);
    event IntentCommitted(bytes32 indexed commitHash, address indexed bot);
    event HuntFired(bytes32 indexed commitHash, address indexed token, uint256 assets);
    event Swept(address indexed token, uint256 amt);

    error Auth();
    error Borders();
    error Bad();
    error Commit();

    modifier onlyBot() {
        if (!bot[msg.sender] && msg.sender != owner) revert Auth();
        _;
    }

    constructor(
        address huntRouter_,
        address hot_,
        address weth_,
        address cbbtc_,
        address usdc_,
        address owner_
    ) Ownable(owner_) {
        require(huntRouter_ != address(0) && hot_ != address(0), "ZERO");
        huntRouter = IHuntRouter(huntRouter_);
        hot = hot_;
        weth = IERC20(weth_);
        cbbtc = IERC20(cbbtc_);
        usdc = IERC20(usdc_);
    }

    function setAttest(address a) external onlyOwner {
        attest = a;
    }

    function setBot(address b, bool ok) external onlyOwner {
        bot[b] = ok;
        emit BotSet(b, ok);
    }

    /// @notice Commit intent hash = keccak(token, assets, targets, datas, salt) off-chain blinded.
    function commitIntent(bytes32 commitHash) external onlyBot {
        if (commitHash == bytes32(0) || committed[commitHash]) revert Bad();
        committed[commitHash] = true;
        emit IntentCommitted(commitHash, msg.sender);
    }

    /// @notice Reveal + hunt. Must match prior commit. ZK borders required if attest set.
    function fire(
        bytes32 commitHash,
        address token,
        uint256 assets,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        uint256 tipErc20,
        bytes32 salt
    ) external payable onlyBot nonReentrant {
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
        if (!committed[commitHash] || consumed[commitHash]) revert Commit();
        bytes32 check = keccak256(abi.encode(token, assets, targets, values, datas, tipErc20, salt));
        if (check != commitHash) revert Commit();
        consumed[commitHash] = true;

        huntRouter.hunt{value: msg.value}(token, assets, targets, values, datas, tipErc20);
        emit HuntFired(commitHash, token, assets);
        _sweep();
    }

    function sweep() external onlyOwner {
        _sweep();
    }

    function _sweep() internal {
        _sweepTok(address(weth));
        _sweepTok(address(cbbtc));
        _sweepTok(address(usdc));
        uint256 ethBal = address(this).balance;
        if (ethBal > 0) {
            (bool ok,) = hot.call{value: ethBal}("");
            require(ok, "ETH");
            emit Swept(address(0), ethBal);
        }
    }

    function _sweepTok(address t) internal {
        uint256 bal = IERC20(t).balanceOf(address(this));
        if (bal == 0) return;
        IERC20(t).safeTransfer(hot, bal);
        emit Swept(t, bal);
    }

    receive() external payable {}
}
