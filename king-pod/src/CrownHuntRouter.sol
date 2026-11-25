// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFlashHunt {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Controlled MEV micro-hunt router — flash → callback executor → tip ETH/USDC to gasSafe.
/// @dev Bots are allowlisted. Kill switch default ON until King arms. No yRSS/Morpho collateral touch.
contract CrownHuntRouter is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFlashHunt public immutable morpho;
    address public gasSafe; // HOT or Ops Safe — hunt tips land here
    bool public killSwitch = true; // SAFE default
    uint256 public minTipWei = 1; // any positive tip counts
    mapping(address => bool) public hunter;
    mapping(address => bool) public targetOk; // allowlisted callee contracts

    bool private _locking;
    address private _activeHunter;

    event HunterSet(address indexed hunter, bool ok);
    event TargetSet(address indexed target, bool ok);
    event GasSafeSet(address indexed gasSafe);
    event KillSwitch(bool on);
    event Hunt(
        address indexed hunter, address indexed token, uint256 flashAmt, uint256 tipWei, uint256 tipErc20
    );

    error Killed();
    error NotHunter();
    error OnlyMorpho();
    error BadTarget();
    error NoTip();

    constructor(address morpho_, address gasSafe_, address owner_) Ownable(owner_) {
        morpho = IMorphoFlashHunt(morpho_);
        gasSafe = gasSafe_;
    }

    receive() external payable {}

    function setKillSwitch(bool on) external onlyOwner {
        killSwitch = on;
        emit KillSwitch(on);
    }

    function setGasSafe(address g) external onlyOwner {
        gasSafe = g;
        emit GasSafeSet(g);
    }

    function setHunter(address h, bool ok) external onlyOwner {
        hunter[h] = ok;
        emit HunterSet(h, ok);
    }

    function setTarget(address t, bool ok) external onlyOwner {
        targetOk[t] = ok;
        emit TargetSet(t, ok);
    }

    function setMinTipWei(uint256 v) external onlyOwner {
        minTipWei = v;
    }

    /// @notice Flash `token` for `assets`, run allowlisted targets/values/datas, tip gasSafe, repay Morpho.
    function hunt(
        address token,
        uint256 assets,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        uint256 tipErc20
    ) external payable nonReentrant {
        if (killSwitch) revert Killed();
        if (!hunter[msg.sender]) revert NotHunter();
        require(targets.length == values.length && values.length == datas.length, "LEN");

        _activeHunter = msg.sender;
        _locking = true;
        morpho.flashLoan(
            token, assets, abi.encode(msg.sender, token, tipErc20, targets, values, datas)
        );
        _locking = false;
        _activeHunter = address(0);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        (
            address hunter_,
            address token,
            uint256 tipErc20,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory datas
        ) = abi.decode(data, (address, address, uint256, address[], uint256[], bytes[]));

        for (uint256 i; i < targets.length; i++) {
            if (!targetOk[targets[i]]) revert BadTarget();
            (bool ok, bytes memory ret) = targets[i].call{value: values[i]}(datas[i]);
            require(ok, string(ret));
        }

        // Tip ETH profit to gasSafe
        uint256 tipWei = address(this).balance;
        if (tipWei > 0) {
            (bool sent,) = gasSafe.call{value: tipWei}("");
            require(sent, "TIP_ETH");
        }

        // Optional ERC20 tip (e.g. leftover dust after arb)
        if (tipErc20 > 0) {
            IERC20(token).safeTransfer(gasSafe, tipErc20);
        }

        // Repay flash (Morpho fee = 0)
        IERC20(token).safeApprove(address(morpho), assets);

        if (tipWei < minTipWei && tipErc20 == 0) revert NoTip();
        emit Hunt(hunter_, token, assets, tipWei, tipErc20);
    }
}
