// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkGateM {
    function isProven(address subject) external view returns (bool);
}

interface IBordersM {
    function bordersSecure() external view returns (bool);
}

interface ISovereignRailM {
    function lltv() external view returns (uint256);
}

interface IMorphoM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function isLltvEnabled(uint256) external view returns (bool);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice Build 4 — one Morpho Blue market on Base: KRT loan / RSS collateral.
/// @dev LLTV policy from SovereignRail (55%). Morpho may not enable exact 55% —
///      fire binds nearest enabled LLTV in doctrine window (62.5% when 55% disabled).
contract CrownMarket_Base_KRT_RSS is Ownable {
    IMorphoM public immutable morpho;
    IZkGateM public immutable zkGate;
    IBordersM public immutable attest;
    ISovereignRailM public immutable sovereignRail;
    address public immutable king;
    address public immutable krt;
    address public immutable rss;
    address public immutable oracle;
    address public immutable irm;

    uint256 public constant MORPHO_625 = 625000000000000000; // nearest enabled ≥ 55%
    uint256 public constant MORPHO_385 = 385000000000000000;

    bytes32 public marketId;
    uint256 public policyLltv;
    uint256 public morphoLltv;
    bool public fired;

    event MarketFired(bytes32 indexed marketId, uint256 policyLltv, uint256 morphoLltv);

    error Auth();
    error AlreadyFired();
    error NotProven();
    error Borders();
    error LltvDisabled();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(
        address morpho_,
        address zkGate_,
        address attest_,
        address sovereignRail_,
        address king_,
        address krt_,
        address rss_,
        address oracle_,
        address irm_,
        address owner_
    ) Ownable(owner_) {
        require(
            morpho_ != address(0) && zkGate_ != address(0) && attest_ != address(0)
                && sovereignRail_ != address(0) && king_ != address(0) && krt_ != address(0)
                && rss_ != address(0) && oracle_ != address(0) && irm_ != address(0),
            "ZERO"
        );
        morpho = IMorphoM(morpho_);
        zkGate = IZkGateM(zkGate_);
        attest = IBordersM(attest_);
        sovereignRail = ISovereignRailM(sovereignRail_);
        king = king_;
        krt = krt_;
        rss = rss_;
        oracle = oracle_;
        irm = irm_;
    }

    /// @notice One fire — create Base KRT/RSS Morpho market.
    function fire() external whenZk returns (bytes32 id) {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        if (fired) revert AlreadyFired();

        policyLltv = sovereignRail.lltv();
        morphoLltv = _bindLltv(policyLltv);

        IMorphoM.MarketParams memory mp =
            IMorphoM.MarketParams(krt, rss, oracle, irm, morphoLltv);
        id = keccak256(abi.encode(mp));

        (address loan,,,,) = morpho.idToMarketParams(id);
        if (loan == address(0)) {
            morpho.createMarket(mp);
        }

        marketId = id;
        fired = true;
        emit MarketFired(id, policyLltv, morphoLltv);
    }

    function _bindLltv(uint256 policy) internal view returns (uint256) {
        if (morpho.isLltvEnabled(policy)) return policy;
        // Base Morpho: 55% disabled — bind 62.5% (doctrine lever ≤ 75%).
        if (morpho.isLltvEnabled(MORPHO_625)) return MORPHO_625;
        if (morpho.isLltvEnabled(MORPHO_385)) return MORPHO_385;
        revert LltvDisabled();
    }
}
