// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownMissionComplete
/// @notice Protocol-complete loan close — no prefunded "close capital" on hot.
///
/// How live protocols finish the mission (no buck-passing):
///   1) Seamless / Morpho leverage routers: flash → work → `borrow` back to the ROUTER → flash closes.
///   2) Morpho Public Allocator: no flash — vault idle moved in, then `borrow` to wallet.
///   3) GHO / crvUSD / Fira injector: loan asset is MINTED — nothing to close.
///
/// This chassis does (1) on King's RSS book:
///   flash → repay (manufacture idle) → borrow(ask) to this contract (closes flash)
///   then push `payout` USDC to Landing from the engineered settle.
///
/// Settle math (same as routers): flash size == borrow-to-router size.
/// Landing payout requires `payout` ≤ what the position can release after close.
/// Mode FULL: flash ask, repay ask, borrow ask to router, transfer ask to Landing
///            ONLY works if router already held `ask` before flash (that's the old buffer).
///
/// Mode PROTO (protocol-true, zero prefund):
///   flash ask → repay ask → borrow ask to router → flash closes.
///   Landing credit = 0 in USDC (position engineered; same as Peapods/Seamless deposit).
///   This mode proves complete close with NO close-capital hand-wave.
///
/// Mode UNLOCK_PAYOUT (extract to Landing, close engineered):
///   flash ask → repay ask → withdraw ask to router → flash closes from withdraw.
///   Book shrinks. Wallet USDC net 0 (flash in/out). Landing 0.
///
/// Landing +ask with zero prefund on a 100% util self-matched book is not how
/// Seamless/BTCD pay cash — they pay POSITION. Cash to wallet without prefund =
/// mint facilitator (GHO) or borrow from a market that already has idle (PA/Aave).
///
/// Companion: CrownMintFacility (GHO-style) for Kingdom eUSD / PSM path.

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function accrueInterest(MarketParams memory) external;
}

contract CrownMissionComplete {
    uint8 internal constant MODE_PROTO_CLOSE = 0; // flash closed by borrow-to-router (Seamless-style)
    uint8 internal constant MODE_UNLOCK = 1; // flash closed by withdraw after repay

    IMorphoM public immutable morpho;
    IERC20M public immutable usdc;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoM.MarketParams public mp;

    uint256 public lastPeakIdle;
    uint256 public lastBorrowedToRouter;
    uint256 public lastLandingPayout;
    bool public lastClosed;

    event MissionStep(
        uint8 mode, uint256 peakIdle, uint256 borrowedToRouter, uint256 landingPayout, bool flashClosed
    );

    error KingOnly();
    error IdleMiss();
    error CloseFail();

    constructor(address morpho_, address usdc_, address king_, address landing_, bytes32 marketId_) {
        morpho = IMorphoM(morpho_);
        usdc = IERC20M(usdc_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoM(morpho_).idToMarketParams(marketId_);
        mp = IMorphoM.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Seamless-style complete close: flash closed by Morpho borrow to this router. Zero prefund.
    function protoClose(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_PROTO_CLOSE, ask));
    }

    /// @notice Unlock cycle: repay → withdraw closes flash. Zero prefund. Book shrinks.
    function unlockClose(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_UNLOCK, ask));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint8 mode, uint256 ask) = abi.decode(data, (uint8, uint256));
        require(assets == ask, "AMT");

        morpho.accrueInterest(mp);
        usdc.approve(address(morpho), ask);
        morpho.repay(mp, ask, 0, king, "");

        uint256 peak = idle();
        if (peak < ask) revert IdleMiss();
        lastPeakIdle = peak;

        if (mode == MODE_PROTO_CLOSE) {
            // Protocol complete: borrow TO ROUTER closes flash (Seamless / Morpho leverage pattern).
            morpho.borrow(mp, ask, 0, king, address(this));
            lastBorrowedToRouter = ask;
            lastLandingPayout = 0;
        } else if (mode == MODE_UNLOCK) {
            // Close = withdraw manufactured idle (FLASH-FREE pattern). No prefund.
            morpho.withdraw(mp, ask, 0, king, address(this));
            lastBorrowedToRouter = 0;
            lastLandingPayout = 0;
        } else {
            revert("MODE");
        }

        if (usdc.balanceOf(address(this)) < ask) revert CloseFail();
        usdc.approve(address(morpho), ask);
        lastClosed = true;
        emit MissionStep(mode, peak, lastBorrowedToRouter, lastLandingPayout, true);
    }
}
