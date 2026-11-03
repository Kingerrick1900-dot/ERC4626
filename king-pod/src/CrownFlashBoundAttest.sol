// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFlash {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IBoundGate {
    function attestLive(address subject, uint256 threshold) external;
    function submitBoundProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata publicSignals
    ) external;
    function isProven(address subject) external view returns (bool);
    function minThreshold() external view returns (uint256);
    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

interface IZkCreditF {
    function operatorBorrowTo(address to, uint256 amt) external;
    function maxBorrow(address user) external view returns (uint256);
    function landing() external view returns (address);
    function king() external view returns (address);
}

/// @notice Morpho flash → park USDC on subject → bound attest → repay same tx.
/// @dev Optional credit poke after unlock: lasting Landing seed only if credit already holds USDC.
///      Flash itself leaves net-zero USDC (repay consumes it). Physics, not hope.
contract CrownFlashBoundAttest is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFlash public immutable morpho;
    IERC20 public immutable usdc;
    IBoundGate public immutable gate;
    address public immutable subject; // Base hot / king
    IZkCreditF public credit; // optional; set by owner
    address public autoDraw; // optional poke target (unused if credit set)

    bool private _locking;

    event BoundFired(address indexed subject, uint256 amount, bytes32 mode, bool proven, uint256 landingDelta);
    event CreditSet(address credit);
    event AutoDrawSet(address autoDraw);

    error OnlyMorpho();
    error NotSubject();
    error BadAmt();
    error Short();
    error NotProven();

    constructor(address morpho_, address usdc_, address gate_, address subject_, address owner_) Ownable(owner_) {
        morpho = IMorphoFlash(morpho_);
        usdc = IERC20(usdc_);
        gate = IBoundGate(gate_);
        subject = subject_;
    }

    function setCredit(address credit_) external onlyOwner {
        credit = IZkCreditF(credit_);
        emit CreditSet(credit_);
    }

    function setAutoDraw(address autoDraw_) external onlyOwner {
        autoDraw = autoDraw_;
        emit AutoDrawSet(autoDraw_);
    }

    /// @notice Flash + attestLive(subject, amount). Subject must approve this for `amount` USDC pullback.
    function fireLive(uint256 amount) external nonReentrant returns (bool proven, uint256 landingDelta) {
        if (msg.sender != subject && msg.sender != owner) revert NotSubject();
        if (amount == 0 || amount < gate.minThreshold()) revert BadAmt();
        uint256 landingBefore = _landingBal();
        _locking = true;
        morpho.flashLoan(address(usdc), amount, abi.encode(uint8(1), amount));
        _locking = false;
        proven = gate.isProven(subject);
        if (!proven) revert NotProven();
        landingDelta = _landingBal() - landingBefore;
        emit BoundFired(subject, amount, bytes32("LIVE_BAL"), proven, landingDelta);
    }

    /// @notice Flash + submitBoundProof. Pre-generate proof for threshold; flash parks that USDC on subject.
    function fireBoundProof(
        uint256 amount,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata publicSignals
    ) external nonReentrant returns (bool proven, uint256 landingDelta) {
        if (msg.sender != subject && msg.sender != owner) revert NotSubject();
        if (amount == 0 || amount < gate.minThreshold()) revert BadAmt();
        if (publicSignals[1] > amount) revert BadAmt();
        if (publicSignals[2] != uint256(uint160(subject))) revert BadAmt();
        uint256 landingBefore = _landingBal();
        _locking = true;
        morpho.flashLoan(
            address(usdc),
            amount,
            abi.encode(uint8(2), amount, a, b, c, publicSignals)
        );
        _locking = false;
        proven = gate.isProven(subject);
        if (!proven) revert NotProven();
        landingDelta = _landingBal() - landingBefore;
        emit BoundFired(subject, amount, bytes32("ZK_BOUND"), proven, landingDelta);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        uint8 mode = abi.decode(data, (uint8));
        // Park flash USDC on subject so balanceOf(subject) is live truth.
        usdc.safeTransfer(subject, assets);

        if (mode == 1) {
            (, uint256 threshold) = abi.decode(data, (uint8, uint256));
            gate.attestLive(subject, threshold);
        } else if (mode == 2) {
            (
                ,
                ,
                uint256[2] memory a,
                uint256[2][2] memory b,
                uint256[2] memory c,
                uint256[3] memory pub
            ) = abi.decode(data, (uint8, uint256, uint256[2], uint256[2][2], uint256[2], uint256[3]));
            gate.submitBoundProof(a, b, c, pub);
        } else {
            revert BadAmt();
        }

        // Optional lasting Landing fill from credit book (not from flash).
        _pokeCredit();

        // Pull flash USDC back from subject and repay Morpho (fee = 0).
        usdc.safeTransferFrom(subject, address(this), assets);
        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.safeApprove(address(morpho), 0);
        usdc.safeApprove(address(morpho), assets);
    }

    function _pokeCredit() internal {
        if (address(credit) == address(0)) return;
        if (!gate.isProven(subject)) return;
        uint256 maxB = credit.maxBorrow(subject);
        if (maxB == 0) return;
        address landing = credit.landing();
        if (landing == address(0)) return;
        credit.operatorBorrowTo(landing, maxB);
    }

    function _landingBal() internal view returns (uint256) {
        if (address(credit) == address(0)) return 0;
        address landing = credit.landing();
        if (landing == address(0)) return 0;
        return usdc.balanceOf(landing);
    }

    /// @notice Sweep dust / mistaken sends to subject.
    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(subject, amt);
    }
}
