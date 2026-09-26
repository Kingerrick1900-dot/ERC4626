// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IYrssNav {
    function totalAssets() external view returns (uint256);
}

interface IColdBuf {
    function balance() external view returns (uint256);
    function meetsRatio(uint256 redeemableWindow) external view returns (bool);
    function minBufferBps() external view returns (uint256);
}

interface IZkSettleGate {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata input
    ) external view returns (bool);
}

/// @notice Third shot: forever attestations across Crown rails.
/// @dev Live view attestations are on-chain facts anyone can re-check (NAV public).
///      Optional Groth16 proofs route through existing King ZK settle gates.
contract CrownZkAttest is Ownable {
    IYrssNav public immutable yrss;
    IColdBuf public cold;
    IZkSettleGate public settleGate;
    IZkSettleGate public elepanGate;

    uint256 public navThreshold; // USDC 6dp
    uint256 public redeemableWindow; // USDC 6dp for 30% law
    uint256 public epoch;
    uint256 public maxStale; // seconds

    struct Attestation {
        uint256 epochId;
        uint256 nav;
        uint256 coldBal;
        bool navMet;
        bool reserveMet;
        bool payrollOk;
        bytes32 payloadHash;
        uint256 timestamp;
        bool snarkOk;
    }

    mapping(uint256 => Attestation) public attestations;
    mapping(bytes32 => bool) public payrollRoots; // committed payroll batch roots
    uint256 public lastAttestTime;

    event ThresholdsSet(uint256 navThreshold, uint256 redeemableWindow, uint256 maxStale);
    event ColdSet(address cold);
    event GatesSet(address settle, address elepan);
    event PayrollRoot(bytes32 indexed root, bool ok);
    event Attested(
        uint256 indexed epochId,
        uint256 nav,
        uint256 coldBal,
        bool navMet,
        bool reserveMet,
        bool payrollOk,
        bool snarkOk,
        bytes32 payloadHash
    );

    error Stale();
    error BadNav();

    constructor(
        address yrss_,
        address owner_,
        uint256 navThreshold_,
        uint256 redeemableWindow_,
        address settleGate_,
        address elepanGate_
    ) Ownable(owner_) {
        yrss = IYrssNav(yrss_);
        navThreshold = navThreshold_;
        redeemableWindow = redeemableWindow_;
        maxStale = 1 hours;
        settleGate = IZkSettleGate(settleGate_);
        elepanGate = IZkSettleGate(elepanGate_);
    }

    function setCold(address cold_) external onlyOwner {
        cold = IColdBuf(cold_);
        emit ColdSet(cold_);
    }

    function setGates(address settle, address elepan) external onlyOwner {
        settleGate = IZkSettleGate(settle);
        elepanGate = IZkSettleGate(elepan);
        emit GatesSet(settle, elepan);
    }

    function setThresholds(uint256 navThreshold_, uint256 redeemableWindow_, uint256 maxStale_)
        external
        onlyOwner
    {
        navThreshold = navThreshold_;
        redeemableWindow = redeemableWindow_;
        maxStale = maxStale_;
        emit ThresholdsSet(navThreshold_, redeemableWindow_, maxStale_);
    }

    function commitPayrollRoot(bytes32 root, bool ok) external onlyOwner {
        payrollRoots[root] = ok;
        emit PayrollRoot(root, ok);
    }

    /// @notice Forever epoch from live on-chain facts (borders set).
    function attestLive(bytes32 payrollRoot) external returns (uint256 epochId) {
        uint256 nav = yrss.totalAssets();
        uint256 coldBal = address(cold) == address(0) ? 0 : cold.balance();
        bool navMet = nav >= navThreshold;
        bool reserveMet =
            address(cold) == address(0) ? false : cold.meetsRatio(redeemableWindow);
        bool payrollOk = payrollRoot == bytes32(0) || payrollRoots[payrollRoot];

        epochId = ++epoch;
        bytes32 payload = keccak256(
            abi.encode(
                block.chainid,
                address(yrss),
                address(cold),
                epochId,
                nav,
                coldBal,
                navMet,
                reserveMet,
                payrollOk,
                payrollRoot,
                block.timestamp
            )
        );

        attestations[epochId] = Attestation({
            epochId: epochId,
            nav: nav,
            coldBal: coldBal,
            navMet: navMet,
            reserveMet: reserveMet,
            payrollOk: payrollOk,
            payloadHash: payload,
            timestamp: block.timestamp,
            snarkOk: false
        });
        lastAttestTime = block.timestamp;
        emit Attested(epochId, nav, coldBal, navMet, reserveMet, payrollOk, false, payload);
    }

    /// @notice Bind a Groth16 proof from existing settle gate to an epoch (third shot steel).
    function attestWithSnark(
        uint256 epochId,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata input,
        bool useElepan
    ) external onlyOwner {
        Attestation storage at = attestations[epochId];
        require(at.timestamp != 0, "EPOCH");
        IZkSettleGate gate = useElepan ? elepanGate : settleGate;
        require(address(gate) != address(0), "GATE");
        require(gate.verifyProof(a, b, c, input), "PROOF");
        at.snarkOk = true;
        emit Attested(
            epochId, at.nav, at.coldBal, at.navMet, at.reserveMet, at.payrollOk, true, at.payloadHash
        );
    }

    function latest() external view returns (Attestation memory) {
        return attestations[epoch];
    }

    /// @notice Constitutional brake: large ops require fresh NAV-met attest.
    function bordersSecure() external view returns (bool) {
        if (epoch == 0) return false;
        Attestation memory at = attestations[epoch];
        if (block.timestamp > at.timestamp + maxStale) return false;
        return at.navMet;
    }

    function requireBorders() external view {
        if (!this.bordersSecure()) revert Stale();
        if (!attestations[epoch].navMet) revert BadNav();
    }
}
