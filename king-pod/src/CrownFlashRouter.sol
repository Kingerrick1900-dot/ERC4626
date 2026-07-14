// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFlash {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Borrower callback: receive flash USDC, must approve router for assets+fee before return.
interface ICrownFlashBorrower {
    function onCrownFlash(uint256 assets, uint256 fee, bytes calldata data) external;
}

/// @notice Crown Flash Router — Morpho 0% wholesale → retail flash with fee to treasury (Aave-style).
contract CrownFlashRouter is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFlash public immutable morpho;
    IERC20 public immutable usdc;
    address public treasury;
    uint256 public feeBps; // e.g. 5 = 0.05%, 9 = 0.09%
    uint256 public constant BPS = 10_000;
    bool public paused;

    address private _initiator;
    uint256 private _flashAssets;
    bytes private _userData;

    event FlashExecuted(address indexed initiator, uint256 assets, uint256 fee, address treasury);
    event FeeUpdated(uint256 feeBps);
    event TreasuryUpdated(address treasury);
    event Paused(bool paused);

    error PausedError();
    error Zero();
    error FeeBps();

    constructor(address morpho_, address usdc_, address treasury_, uint256 feeBps_, address owner_) Ownable(owner_) {
        require(morpho_ != address(0) && usdc_ != address(0) && treasury_ != address(0), "ZERO");
        if (feeBps_ == 0 || feeBps_ > 100) revert FeeBps(); // max 1%
        morpho = IMorphoFlash(morpho_);
        usdc = IERC20(usdc_);
        treasury = treasury_;
        feeBps = feeBps_;
    }

    function setFeeBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps > 100) revert FeeBps();
        feeBps = bps;
        emit FeeUpdated(bps);
    }

    function setTreasury(address t) external onlyOwner {
        require(t != address(0), "ZERO");
        treasury = t;
        emit TreasuryUpdated(t);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    function quoteFee(uint256 assets) public view returns (uint256) {
        return (assets * feeBps) / BPS;
    }

    /// @notice Flash USDC via Morpho 0%. Caller must implement ICrownFlashBorrower and approve assets+fee.
    function flashLoan(uint256 assets, bytes calldata data) external nonReentrant {
        if (paused) revert PausedError();
        if (assets == 0) revert Zero();
        _initiator = msg.sender;
        _flashAssets = assets;
        _userData = data;
        morpho.flashLoan(address(usdc), assets, bytes(""));
        _initiator = address(0);
        _flashAssets = 0;
        delete _userData;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        require(msg.sender == address(morpho), "MORPHO");
        address initiator = _initiator;
        require(initiator != address(0), "INIT");
        require(assets == _flashAssets, "AMT");

        uint256 fee = quoteFee(assets);
        // Send principal to borrower
        usdc.safeTransfer(initiator, assets);
        // Borrower executes strategy
        ICrownFlashBorrower(initiator).onCrownFlash(assets, fee, _userData);
        // Pull principal + fee
        usdc.safeTransferFrom(initiator, address(this), assets + fee);
        // Fee to treasury
        if (fee > 0) usdc.safeTransfer(treasury, fee);
        // Morpho pulls principal back
        usdc.safeApprove(address(morpho), assets);

        emit FlashExecuted(initiator, assets, fee, treasury);
    }

    function rescue(address token, uint256 amt, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amt);
    }
}
