// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IAssets {
    function totalAssets() external view returns (uint256);
}

interface ITok {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface ICold {
    function balance() external view returns (uint256);
}

interface IZkAttestView {
    function bordersSecure() external view returns (bool);
    function epoch() external view returns (uint256);
    function payrollRoots(bytes32) external view returns (bool);
    function attestations(uint256)
        external
        view
        returns (
            uint256 epochId,
            uint256 nav,
            uint256 coldBal,
            bool navMet,
            bool reserveMet,
            bool payrollOk,
            bytes32 payloadHash,
            uint256 timestamp,
            bool snarkOk
        );
}

/// @title CrownSovereignBoard
/// @notice Public three-rail NAV board. ZK-attested only — no capacity, no potential.
/// @dev Gold / Ocean / Landing. Owner publishes snapshot; HOT binds root into CrownZkAttest.
contract CrownSovereignBoard is Ownable {
    IAssets public immutable yrss;
    ITok public immutable eusd;
    ITok public immutable gusd;
    address public immutable landing;
    address public immutable oceanPool;
    ICold public immutable cold;
    IZkAttestView public attest;

    struct GoldRail {
        uint256 lockedGoldUsd6;
        uint256 idleRealEusd18;
        uint256 mintedRealEusd18;
    }

    struct OceanRail {
        uint256 eusdOcean18;
        uint256 gusdOcean18;
        uint256 depth18;
    }

    struct LandingRail {
        uint256 idleEusd18;
        bool payrollLive;
        uint256 coldBufferUsd6;
    }

    struct Board {
        GoldRail gold;
        OceanRail ocean;
        LandingRail landingChest;
        uint64 updatedAt;
        uint256 attestEpoch;
        bytes32 root;
        bytes32 attestPayload;
        bool bordersSecure;
        bool rootWired;
    }

    Board public latest;

    event BoardPublished(bytes32 indexed root, uint64 updatedAt);
    event AttestWired(bytes32 indexed root, uint256 epoch, bytes32 payload);
    event AttestSet(address attest);

    constructor(
        address yrss_,
        address eusd_,
        address gusd_,
        address landing_,
        address oceanPool_,
        address cold_,
        address attest_,
        address owner_
    ) Ownable(owner_) {
        require(
            yrss_ != address(0) && eusd_ != address(0) && gusd_ != address(0) && landing_ != address(0)
                && oceanPool_ != address(0) && cold_ != address(0),
            "ZERO"
        );
        yrss = IAssets(yrss_);
        eusd = ITok(eusd_);
        gusd = ITok(gusd_);
        landing = landing_;
        oceanPool = oceanPool_;
        cold = ICold(cold_);
        attest = IZkAttestView(attest_);
    }

    function setAttest(address a) external onlyOwner {
        attest = IZkAttestView(a);
        emit AttestSet(a);
    }

    /// @notice Live rails for dashboard / auditors (no storage write).
    function readRails()
        external
        view
        returns (GoldRail memory gold, OceanRail memory ocean, LandingRail memory land, bool borders)
    {
        (gold, ocean, land) = _rails();
        borders = address(attest) != address(0) && attest.bordersSecure();
    }

    /// @notice Snapshot on-chain truth into board + root. Does not call ZkAttest (HOT wires next).
    function publish() external onlyOwner returns (bytes32 root) {
        (GoldRail memory gold, OceanRail memory ocean, LandingRail memory land) = _rails();

        root = keccak256(
            abi.encode(
                block.chainid,
                address(yrss),
                oceanPool,
                landing,
                gold.lockedGoldUsd6,
                gold.idleRealEusd18,
                gold.mintedRealEusd18,
                ocean.eusdOcean18,
                ocean.gusdOcean18,
                ocean.depth18,
                land.idleEusd18,
                land.payrollLive,
                land.coldBufferUsd6,
                block.timestamp
            )
        );

        bool borders = address(attest) != address(0) && attest.bordersSecure();

        latest = Board({
            gold: gold,
            ocean: ocean,
            landingChest: land,
            updatedAt: uint64(block.timestamp),
            attestEpoch: 0,
            root: root,
            attestPayload: bytes32(0),
            bordersSecure: borders,
            rootWired: false
        });

        emit BoardPublished(root, uint64(block.timestamp));
    }

    /// @notice Record ZkAttest epoch after HOT `commitPayrollRoot` + `attestLive` with board root.
    function recordWire(uint256 epochId) external onlyOwner {
        require(latest.root != bytes32(0), "NO_ROOT");
        require(address(attest) != address(0), "NO_ATTEST");
        require(attest.payrollRoots(latest.root), "ROOT");
        (
            ,
            ,
            ,
            ,
            ,
            ,
            bytes32 payload,
            ,
        ) = attest.attestations(epochId);
        latest.attestEpoch = epochId;
        latest.attestPayload = payload;
        latest.bordersSecure = attest.bordersSecure();
        latest.rootWired = true;
        latest.landingChest.payrollLive = true;
        emit AttestWired(latest.root, epochId, payload);
    }

    function _rails()
        internal
        view
        returns (GoldRail memory gold, OceanRail memory ocean, LandingRail memory land)
    {
        uint256 idle = eusd.balanceOf(landing);
        gold = GoldRail({
            lockedGoldUsd6: yrss.totalAssets(),
            idleRealEusd18: idle,
            mintedRealEusd18: eusd.totalSupply()
        });
        uint256 eO = eusd.balanceOf(oceanPool);
        uint256 gO = gusd.balanceOf(oceanPool);
        ocean = OceanRail({eusdOcean18: eO, gusdOcean18: gO, depth18: eO + gO});

        bool payroll = false;
        if (address(attest) != address(0) && attest.epoch() > 0) {
            (,,,,, payroll,,,) = attest.attestations(attest.epoch());
        }
        land = LandingRail({idleEusd18: idle, payrollLive: payroll, coldBufferUsd6: cold.balance()});
    }
}
