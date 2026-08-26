// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrownBorrowCapacity} from "./CrownBorrowCapacity.sol";

interface IMorphoBack {
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IErc20Back {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IGusdBack {
    function totalSupply() external view returns (uint256);
    function eusdFloat() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface INotesBack {
    function canIssue() external view returns (bool);
    function borrowCapacity() external view returns (uint256);
    function armed() external view returns (bool);
}

interface IFxBack {
    function armed() external view returns (bool);
    function borrowCapacity() external view returns (uint256);
    function idleUsdc() external view returns (uint256);
}

/// @title CrownBackingScribe
/// @notice Phase 1: every minted eUSD/gUSD attested against RSS Morpho books + capacity. No loans.
/// @dev RSS-only doctrine. gUSD must equal eUSD locked in wrapper. Engine must stay cold in freeze.
contract CrownBackingScribe {
    address public immutable morpho;
    address public immutable eusd;
    address public immutable gusd;
    address public immutable rss;
    address public immutable king;
    bytes32 public immutable midEusd50;
    bytes32 public immutable midGusd50;
    bytes32 public immutable midUsdc1200;
    address public notes;
    address public fxEngine;

    struct Seal {
        uint256 eusdTotal;
        uint256 gusdTotal;
        uint256 gusdEusdFloat; // eUSD locked in gUSD wrapper
        uint256 hotGusd;
        uint256 eusdBookSupply;
        uint256 eusdBookBorrow;
        uint256 eusdBookIdle;
        uint256 gusdBookSupply;
        uint256 gusdBookBorrow;
        uint256 gusdBookIdle;
        uint256 rssCollEusdBook; // King RSS on eUSD/$50k
        uint256 rssCollGusdBook; // King RSS on gUSD/$50k
        uint256 rssCollUsdcBook; // King RSS on USDC/$1200
        uint256 usdcBorrowCapacity; // 6dp headroom
        bool gusdFullyBacked; // gusdTotal == eusdFloat
        bool notesCanIssue;
        bool fxArmed;
        bool freezeCold; // !fxArmed
        bool sealOk; // gusdFullyBacked && notesCanIssue && freezeCold
        uint256 blockNumber;
        uint256 timestamp;
    }

    Seal public latest;
    event BackingSealed(
        uint256 blockNumber,
        uint256 eusdTotal,
        uint256 gusdTotal,
        uint256 usdcBorrowCapacity,
        bool sealOk
    );

    constructor(
        address morpho_,
        address eusd_,
        address gusd_,
        address rss_,
        address king_,
        bytes32 midEusd50_,
        bytes32 midGusd50_,
        bytes32 midUsdc1200_,
        address notes_,
        address fxEngine_
    ) {
        morpho = morpho_;
        eusd = eusd_;
        gusd = gusd_;
        rss = rss_;
        king = king_;
        midEusd50 = midEusd50_;
        midGusd50 = midGusd50_;
        midUsdc1200 = midUsdc1200_;
        notes = notes_;
        fxEngine = fxEngine_;
    }

    function setRails(address notes_, address fxEngine_) external {
        require(msg.sender == king, "KING");
        notes = notes_;
        fxEngine = fxEngine_;
    }

    /// @notice Phase 1 snap — attest float backing. Does not borrow.
    function seal() external returns (Seal memory s) {
        s.eusdTotal = IErc20Back(eusd).totalSupply();
        s.gusdTotal = IGusdBack(gusd).totalSupply();
        s.gusdEusdFloat = IGusdBack(gusd).eusdFloat();
        s.hotGusd = IGusdBack(gusd).balanceOf(king);

        (uint128 es,, uint128 eb,,,) = IMorphoBack(morpho).market(midEusd50);
        s.eusdBookSupply = es;
        s.eusdBookBorrow = eb;
        s.eusdBookIdle = es > eb ? uint256(es) - uint256(eb) : 0;

        (uint128 gs,, uint128 gb,,,) = IMorphoBack(morpho).market(midGusd50);
        s.gusdBookSupply = gs;
        s.gusdBookBorrow = gb;
        s.gusdBookIdle = gs > gb ? uint256(gs) - uint256(gb) : 0;

        (,, uint128 cE) = IMorphoBack(morpho).position(midEusd50, king);
        (,, uint128 cG) = IMorphoBack(morpho).position(midGusd50, king);
        (,, uint128 cU) = IMorphoBack(morpho).position(midUsdc1200, king);
        s.rssCollEusdBook = cE;
        s.rssCollGusdBook = cG;
        s.rssCollUsdcBook = cU;

        s.usdcBorrowCapacity = CrownBorrowCapacity.borrowCapacity(morpho, midUsdc1200, king);
        s.gusdFullyBacked = (s.gusdTotal == s.gusdEusdFloat);

        if (notes != address(0)) {
            s.notesCanIssue = INotesBack(notes).canIssue();
        }
        if (fxEngine != address(0)) {
            s.fxArmed = IFxBack(fxEngine).armed();
        }
        s.freezeCold = !s.fxArmed;
        s.sealOk = s.gusdFullyBacked && s.notesCanIssue && s.freezeCold;
        s.blockNumber = block.number;
        s.timestamp = block.timestamp;

        latest = s;
        emit BackingSealed(s.blockNumber, s.eusdTotal, s.gusdTotal, s.usdcBorrowCapacity, s.sealOk);
    }

    /// @notice Phase 2 view — cold rails checklist (no state change).
    function railsCold()
        external
        view
        returns (bool notesOk, bool engineCold, bool capacityGe10m, bool readyToArmLater)
    {
        notesOk = notes != address(0) && INotesBack(notes).canIssue();
        engineCold = fxEngine == address(0) || !IFxBack(fxEngine).armed();
        uint256 cap = CrownBorrowCapacity.borrowCapacity(morpho, midUsdc1200, king);
        capacityGe10m = cap >= 10_000_000e6;
        // Ready checklist: backed gate + cold engine + capacity. Arm is King-only later.
        readyToArmLater = notesOk && engineCold && capacityGe10m;
    }
}
