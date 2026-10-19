// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";
import {CrownKRT} from "./CrownKRT.sol";

interface IMorphoCredit {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv);
}

interface IOracleCredit {
    function price() external view returns (uint256);
}

interface IZkGateCredit {
    function isProven(address subject) external view returns (bool);
}

interface IBordersCredit {
    function bordersSecure() external view returns (bool);
}

/// @notice Bridge: mint KRT against Killer PAR RSS collateral (200% OC). Safe authority.
/// @dev Does NOT supply yRSS (USDC-only). Manufactured KRT seeds KRT/USDC Ocean.
contract CrownSovereignCredit is Ownable {
    uint256 public constant OC_BPS = 20_000; // 200% collateral / debt
    uint256 public constant BPS = 10_000;
    uint256 public constant ORACLE_SCALE = 1e36;
    uint256 public constant COLD_BPS = 2_000; // 20%

    IMorphoCredit public immutable morpho;
    IZkGateCredit public immutable zkGate;
    IBordersCredit public immutable attest;
    bytes32 public immutable marketId;
    address public immutable collateralHolder; // Killer
    address public immutable king; // Safe
    address public immutable rss;
    address public immutable oracle;

    CrownKRT public krt;
    address public coldBuffer;
    uint256 public totalMinted;
    uint256 public coldLocked;

    event KrtWired(address indexed krt);
    event ColdWired(address indexed cold);
    event CreditMinted(address indexed to, uint256 amount, uint256 collWei, uint256 maxMint);
    event ColdLocked(uint256 amount);

    error Auth();
    error NotWired();
    error NotProven();
    error Borders();
    error OverCap();
    error NoCollateral();
    error Zero();

    modifier onlyKing() {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(
        address morpho_,
        address zkGate_,
        address attest_,
        bytes32 marketId_,
        address collateralHolder_,
        address rss_,
        address oracle_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        require(
            morpho_ != address(0) && zkGate_ != address(0) && attest_ != address(0)
                && collateralHolder_ != address(0) && rss_ != address(0) && oracle_ != address(0)
                && king_ != address(0),
            "ZERO"
        );
        morpho = IMorphoCredit(morpho_);
        zkGate = IZkGateCredit(zkGate_);
        attest = IBordersCredit(attest_);
        marketId = marketId_;
        collateralHolder = collateralHolder_;
        rss = rss_;
        oracle = oracle_;
        king = king_;
    }

    function wireKrt(address krt_) external onlyKing {
        require(krt_ != address(0), "ZERO");
        krt = CrownKRT(krt_);
        emit KrtWired(krt_);
    }

    function wireCold(address cold_) external onlyKing {
        require(cold_ != address(0), "ZERO");
        coldBuffer = cold_;
        emit ColdWired(cold_);
    }

    /// @notice Killer PAR RSS collateral (wei) and max KRT mint at 200% OC ($1 KRT).
    function creditCapacity()
        public
        view
        returns (uint256 collWei, uint256 collUsd6, uint256 maxMint18, uint256 minted)
    {
        (,, uint128 coll) = morpho.position(marketId, collateralHolder);
        collWei = uint256(coll);
        if (collWei == 0) return (0, 0, 0, totalMinted);
        uint256 px = IOracleCredit(oracle).price();
        // Morpho: loan-token value (USDC 6dp) = coll * price / 1e36
        collUsd6 = collWei * px / ORACLE_SCALE;
        // KRT 18dp at $1: scale USDC 6dp → 18dp, then / 2 for 200% OC
        uint256 collUsd18 = collUsd6 * 1e12;
        maxMint18 = (collUsd18 * BPS) / OC_BPS;
        minted = totalMinted;
    }

    /// @notice Mint KRT against live Killer PAR RSS. Cap = 200% OC.
    function mintCredit(address to, uint256 amount) external onlyKing whenZk returns (uint256) {
        return _mintCredit(to, amount);
    }

    /// @notice Mint full ask, lock 20% into coldBuffer, send 80% to `to`.
    function mintAndSplit(address to, uint256 amount)
        external
        onlyKing
        whenZk
        returns (uint256 toHot, uint256 toCold)
    {
        if (address(krt) == address(0) || coldBuffer == address(0)) revert NotWired();
        if (to == address(0) || amount == 0) revert Zero();

        _mintCredit(address(this), amount);
        toCold = (amount * COLD_BPS) / BPS;
        toHot = amount - toCold;
        require(krt.transfer(coldBuffer, toCold), "COLD");
        require(krt.transfer(to, toHot), "HOT");
        coldLocked += toCold;
        emit ColdLocked(toCold);
    }

    function _mintCredit(address to, uint256 amount) internal returns (uint256) {
        if (address(krt) == address(0)) revert NotWired();
        if (to == address(0) || amount == 0) revert Zero();
        (uint256 collWei,, uint256 maxMint,) = creditCapacity();
        if (collWei == 0) revert NoCollateral();
        if (totalMinted + amount > maxMint) revert OverCap();

        totalMinted += amount;
        krt.mint(to, amount);
        emit CreditMinted(to, amount, collWei, maxMint);
        return amount;
    }
}
