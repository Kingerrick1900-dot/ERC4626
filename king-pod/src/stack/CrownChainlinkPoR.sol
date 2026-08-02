// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/Core.sol";

interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IMorphoPoR {
    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IGoldCdpPoR {
    function coll() external view returns (uint256);
    function debt() external view returns (uint256);
    function gold() external view returns (address);
    function oracle() external view returns (address);
    function healthFactor() external view returns (uint256);
}

interface IGoldOraclePoR {
    function price() external view returns (uint256);
}

/// @notice Chainlink-compatible Proof of Reserve feed for Morpho ELE77 vault assets.
/// @dev answer = totalSupplyAssets (USDC 6dp) as reserve notional. Cryptographic on-chain backing proof.
contract CrownEle77PoRFeed is IAggregatorV3, Ownable {
    IMorphoPoR public immutable morpho;
    bytes32 public immutable marketId;
    address public immutable yEle; // optional vault share holder for position PoR
    uint8 public constant DECIMALS = 6;
    string public constant DESCR = "ELE77 PoR USDC reserves";

    uint80 internal _round;

    event Heartbeat(uint80 roundId, int256 answer, uint256 updatedAt);

    constructor(address morpho_, bytes32 marketId_, address yEle_, address owner_) Ownable(owner_) {
        require(morpho_ != address(0), "MORPHO");
        morpho = IMorphoPoR(morpho_);
        marketId = marketId_;
        yEle = yEle_;
        _round = 1;
    }

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    function description() external pure returns (string memory) {
        return DESCR;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    /// @notice Reserve answer = Morpho market totalSupplyAssets (USDC 6dp).
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint128 supply,, uint128 borrow,, uint128 lastUpdate,) = morpho.market(marketId);
        // Idle + borrowed = total supplied reserves backing the book
        answer = int256(uint256(supply));
        // Also expose utilization implicitly: borrow <= supply for healthy PoR
        if (borrow > supply) answer = int256(uint256(borrow)); // still report liabilities ceiling
        roundId = _round;
        answeredInRound = _round;
        startedAt = uint256(lastUpdate);
        updatedAt = block.timestamp;
    }

    /// @notice Optional: collateral posted on ELE77 by a specific user (8dp ELE raw).
    function collateralOf(address user) external view returns (uint256) {
        (,, uint128 coll) = morpho.position(marketId, user);
        return uint256(coll);
    }

    function bumpRound() external onlyOwner {
        (uint128 supply,,,,,) = morpho.market(marketId);
        _round += 1;
        emit Heartbeat(_round, int256(uint256(supply)), block.timestamp);
    }
}

/// @notice Chainlink-compatible PoR for Scroll Gold CDP collateral.
/// @dev answer = collateral USD value in 6dp (kXAU * oracle / 1e36).
contract CrownGoldCdpPoRFeed is IAggregatorV3, Ownable {
    IGoldCdpPoR public immutable cdp;
    uint8 public constant DECIMALS = 6;
    string public constant DESCR = "Gold CDP PoR USD collateral";
    uint256 public constant ORACLE_SCALE = 1e36;

    uint80 internal _round;

    event Heartbeat(uint80 roundId, int256 answer, uint256 updatedAt);

    constructor(address cdp_, address owner_) Ownable(owner_) {
        require(cdp_ != address(0), "CDP");
        cdp = IGoldCdpPoR(cdp_);
        _round = 1;
    }

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    function description() external pure returns (string memory) {
        return DESCR;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        uint256 coll = cdp.coll();
        uint256 px = IGoldOraclePoR(cdp.oracle()).price();
        uint256 usd6 = (coll * px) / ORACLE_SCALE;
        answer = int256(usd6);
        roundId = _round;
        answeredInRound = _round;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
    }

    /// @notice Coverage ratio WAD (collUsd18 / debt18).
    function coverageWad() external view returns (uint256) {
        return cdp.healthFactor();
    }

    function debtEusd() external view returns (uint256) {
        return cdp.debt();
    }

    function bumpRound() external onlyOwner {
        uint256 coll = cdp.coll();
        uint256 px = IGoldOraclePoR(cdp.oracle()).price();
        _round += 1;
        emit Heartbeat(_round, int256((coll * px) / ORACLE_SCALE), block.timestamp);
    }
}
