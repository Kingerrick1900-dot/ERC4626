// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IZkGateBook, ZkKingGate} from "./lib/ZkKingGate.sol";

/// @title CrownZkLayeredLanding
/// @notice ZK layering FIRST — not “own 380 WETH”. Pack unlocks credit; WETH idle is optional layer.
///
/// Live Base stack (already fired once; TTL 7d — refresh when expired):
///   BoundGate  0xab2856626BBd8E6fba9dB93783029eB973E8427F
///   Credit     0x20B1513a137b9CB166E2cC15c405e842278E7D1A
///   FlashAttest 0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4
///   AutoDraw   0x364bEF6c5A3DC2c02D7ECf1e12a2d1F08B0513ba
///
/// Layers (poke tries in order):
///   Z — pack: gate.isProven(king)  (Morpho flash-bound attest; net-zero pocket USDC)
///   C — credit: maxBorrow > 0 → operatorBorrowTo(Landing) / autodraw
///   W — WETH idle TAKE when engineered equity exists (never assumed inventory)
///
/// Physics: isProven ≠ Landing cash. Caps ≠ cash. Flash-bound unlocks the ticket;
/// lasting USDC still needs named source (matcher supply into credit, or engineered
/// blue-chip coll on Morpho idle). 380 WETH ≈ LTV ask for $700k @ 86% — engineer it,
/// do not pretend hot holds it.

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
}

interface IFlashBound {
    function fireLive(uint256 amount) external returns (bool proven, uint256 landingDelta);
    function subject() external view returns (address);
}

interface IZkCreditL {
    function maxBorrow(address user) external view returns (uint256);
    function operatorBorrowTo(address to, uint256 amt) external;
    function king() external view returns (address);
    function landing() external view returns (address);
}

interface IZkAutoDraw {
    function poke() external returns (uint256);
    function ready() external view returns (bool);
}

interface IWethTake {
    function ready() external view returns (bool);
    function poke() external returns (uint256);
    function askUsdc() external view returns (uint256);
    function idle() external view returns (uint256);
}

contract CrownZkLayeredLanding {
    using ZkKingGate for IZkGateBook;

    IZkGateBook public immutable gate;
    IFlashBound public immutable flashBound;
    IZkCreditL public immutable credit;
    IZkAutoDraw public immutable autoDraw;
    IERC20L public immutable usdc;
    address public immutable king;
    address public immutable landing;

    IWethTake public wethTake; // optional — set when TAKE is live
    uint256 public askUsdc;
    bool public paused;

    uint256 public lastLayer; // 1=credit, 2=weth
    uint256 public lastLandingCredit;

    event Armed(uint256 askUsdc, address wethTake);
    event PackRefreshed(bool proven, uint256 landingDelta);
    event LayerPoked(uint8 layer, uint256 landingDelta, address caller);
    event Paused(bool paused);

    error KingOnly();
    error PausedErr();
    error PackMiss();
    error NoLayer();
    error LandingMiss();
    error BadAmt();

    modifier onlyKing() {
        if (msg.sender != king) revert KingOnly();
        _;
    }

    constructor(
        address gate_,
        address flashBound_,
        address credit_,
        address autoDraw_,
        address usdc_,
        address king_,
        address landing_,
        uint256 askUsdc_
    ) {
        gate = IZkGateBook(gate_);
        flashBound = IFlashBound(flashBound_);
        credit = IZkCreditL(credit_);
        autoDraw = IZkAutoDraw(autoDraw_);
        usdc = IERC20L(usdc_);
        king = king_;
        landing = landing_;
        askUsdc = askUsdc_ == 0 ? 700_000e6 : askUsdc_;
        require(credit.king() == king_ && credit.landing() == landing_, "CREDIT_CFG");
        require(flashBound.subject() == king_, "FLASH_SUBJECT");
    }

    function setWethTake(address take_) external onlyKing {
        wethTake = IWethTake(take_);
        emit Armed(askUsdc, take_);
    }

    function setAsk(uint256 askUsdc_) external onlyKing {
        if (askUsdc_ == 0) revert BadAmt();
        askUsdc = askUsdc_;
        emit Armed(askUsdc_, address(wethTake));
    }

    function setPaused(bool p) external onlyKing {
        paused = p;
        emit Paused(p);
    }

    /// @notice Layer Z status — loan ticket. False when TTL expired (7d).
    function packReady() public view returns (bool) {
        if (!gate.isProven(king)) return false;
        (uint256 value,, bool valid) = gate.attestations(king);
        return valid && value >= gate.minThreshold();
    }

    /// @notice Layer C — lasting Landing only if credit holds USDC against pack.
    function creditReady() public view returns (bool) {
        if (!packReady()) return false;
        return credit.maxBorrow(king) >= askUsdc;
    }

    /// @notice Layer W — Morpho WETH/USDC idle. Equity must be engineered; never assumed.
    function wethReady() public view returns (bool) {
        if (address(wethTake) == address(0)) return false;
        return wethTake.ready();
    }

    function ready() external view returns (bool) {
        if (paused) return false;
        return creditReady() || wethReady();
    }

    /// @notice Refresh pack via LIVE FlashBoundAttest (Morpho flash → attestLive → repay).
    /// @dev Hot must approve flashBound for `amount` USDC pullback. Net pocket USDC = 0.
    ///      Landing Δ from this call is 0 unless credit was pre-funded.
    function refreshPack(uint256 amount) external returns (bool proven, uint256 flashLandingDelta) {
        if (paused) revert PausedErr();
        if (msg.sender != king && msg.sender != address(this)) revert KingOnly();
        if (amount == 0) amount = gate.minThreshold();
        (proven, flashLandingDelta) = flashBound.fireLive(amount);
        emit PackRefreshed(proven, flashLandingDelta);
        if (!proven) revert PackMiss();
    }

    /// @notice Permissionless layered poke. Prefers ZK credit (no WETH), else WETH TAKE.
    function poke() external returns (uint256 landingDelta) {
        if (paused) revert PausedErr();
        uint256 before = usdc.balanceOf(landing);

        if (creditReady()) {
            // Prefer autodraw if it exposes ready; else operator borrow
            if (address(autoDraw) != address(0)) {
                try autoDraw.ready() returns (bool ok) {
                    if (ok) {
                        autoDraw.poke();
                        landingDelta = usdc.balanceOf(landing) - before;
                        if (landingDelta < askUsdc) revert LandingMiss();
                        lastLayer = 1;
                        lastLandingCredit = landingDelta;
                        emit LayerPoked(1, landingDelta, msg.sender);
                        return landingDelta;
                    }
                } catch {}
            }
            credit.operatorBorrowTo(landing, askUsdc);
            landingDelta = usdc.balanceOf(landing) - before;
            if (landingDelta < askUsdc) revert LandingMiss();
            lastLayer = 1;
            lastLandingCredit = landingDelta;
            emit LayerPoked(1, landingDelta, msg.sender);
            return landingDelta;
        }

        if (wethReady()) {
            wethTake.poke();
            landingDelta = usdc.balanceOf(landing) - before;
            if (landingDelta < askUsdc) revert LandingMiss();
            lastLayer = 2;
            lastLandingCredit = landingDelta;
            emit LayerPoked(2, landingDelta, msg.sender);
            return landingDelta;
        }

        revert NoLayer();
    }

    /// @notice Scoreboard for ops / desks (pack ticket + rails).
    function book()
        external
        view
        returns (
            bool proven,
            uint256 attestUsdc6,
            uint256 creditMax,
            bool creditOk,
            bool wethOk,
            uint256 landingUsdc
        )
    {
        proven = packReady();
        attestUsdc6 = gate.attestValue(king);
        creditMax = credit.maxBorrow(king);
        creditOk = creditReady();
        wethOk = wethReady();
        landingUsdc = usdc.balanceOf(landing);
    }
}
