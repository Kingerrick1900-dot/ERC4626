// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownEngineerIdle
/// @notice Morpho position broadcast — engineer idle numbers, then Morpho loans against them.
///
/// Same concept as a Morpho self-lend broadcast: flash capital shapes the book, Morpho
/// `borrow` pays what idle shows, flash closes from that loan leg. No third party.
///
/// Idle = supply − borrow. Raise it from the loan book (`repay`) or unmatched `supply`.
/// If Morpho sees $1M idle, Morpho will loan $1M against King's RSS coll (LLTV permitting).

interface IERC20I {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoI {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function accrueInterest(MarketParams memory) external;
}

contract CrownEngineerIdle {
    uint8 internal constant MODE_BROADCAST = 0; // repay → idle → borrow-to-self (Morpho loan closes flash)
    uint8 internal constant MODE_LAND = 1; // repay → idle → borrow-to-Landing (loan receiver = Landing)
    uint8 internal constant MODE_SUPPLY = 2; // unmatched supply → lasting idle on the book

    IMorphoI public immutable morpho;
    IERC20I public immutable usdc;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoI.MarketParams public mp;

    uint256 public lastPeakIdle;
    uint256 public lastLoan;
    uint256 public lastMode;

    struct IdleProof {
        uint256 peakIdle;
        uint256 ask;
        uint256 blockNumber;
        uint256 timestamp;
        bytes32 marketId;
        bool ok;
    }

    IdleProof public lastProof;
    event IdleBroadcast(
        bytes32 indexed marketId, uint256 peakIdle, uint256 loaned, address receiver, uint256 blockNumber
    );

    error KingOnly();
    error IdleMiss();
    error CloseFail();

    constructor(address morpho_, address usdc_, address king_, address landing_, bytes32 marketId_) {
        morpho = IMorphoI(morpho_);
        usdc = IERC20I(usdc_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoI(morpho_).idToMarketParams(marketId_);
        mp = IMorphoI.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Broadcast: engineer idle to `ask`, Morpho loans `ask` (closes flash). Scribe keeps the proof.
    function broadcastIdleLoan(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_BROADCAST, ask));
    }

    /// @notice Same broadcast, Morpho loan receiver = Landing. Chassis must hold `ask` USDC to close flash.
    function broadcastIdleLoanToLanding(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        if (usdc.balanceOf(address(this)) < ask) {
            require(usdc.transferFrom(king, address(this), ask), "CLOSE");
        }
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_LAND, ask));
    }

    /// @notice Lasting idle on the book via unmatched supply (position engineering).
    function engineerLastingIdle(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        require(usdc.transferFrom(king, address(this), ask), "USDC");
        usdc.approve(address(morpho), ask);
        morpho.accrueInterest(mp);
        morpho.supply(mp, ask, 0, king, "");
        uint256 i = idle();
        if (i < ask) revert IdleMiss();
        _scribe(i, ask, MODE_SUPPLY, address(0), 0);
    }

    // Back-compat aliases
    function proveIdleFromLoanBook(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_BROADCAST, ask));
    }

    function idleThenLoanToLanding(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        if (usdc.balanceOf(address(this)) < ask) {
            require(usdc.transferFrom(king, address(this), ask), "CLOSE");
        }
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_LAND, ask));
    }

    function idleFromUnmatchedSupply(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        require(usdc.transferFrom(king, address(this), ask), "USDC");
        usdc.approve(address(morpho), ask);
        morpho.accrueInterest(mp);
        morpho.supply(mp, ask, 0, king, "");
        uint256 i = idle();
        if (i < ask) revert IdleMiss();
        _scribe(i, ask, MODE_SUPPLY, address(0), 0);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint8 mode, uint256 ask) = abi.decode(data, (uint8, uint256));
        require(assets == ask, "AMT");

        morpho.accrueInterest(mp);

        // Engineer the numbers: repay own debt → Morpho idle = ask
        usdc.approve(address(morpho), ask);
        morpho.repay(mp, ask, 0, king, "");

        uint256 peak = idle();
        if (peak < ask) revert IdleMiss();

        address receiver = mode == MODE_LAND ? landing : address(this);
        morpho.borrow(mp, ask, 0, king, receiver);
        _scribe(peak, ask, mode, receiver, ask);

        if (usdc.balanceOf(address(this)) < ask) revert CloseFail();
        usdc.approve(address(morpho), ask);
    }

    function _scribe(uint256 peak, uint256 ask, uint8 mode, address receiver, uint256 loaned) internal {
        lastPeakIdle = peak;
        lastLoan = loaned;
        lastMode = mode;
        lastProof = IdleProof({
            peakIdle: peak,
            ask: ask,
            blockNumber: block.number,
            timestamp: block.timestamp,
            marketId: marketId,
            ok: true
        });
        emit IdleBroadcast(marketId, peak, loaned, receiver, block.number);
    }
}
