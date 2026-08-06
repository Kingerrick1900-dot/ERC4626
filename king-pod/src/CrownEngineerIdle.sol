// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownEngineerIdle
/// @notice CORRECT Morpho idle engineers (not Aero optics, not fake accounting).
///
/// Morpho Blue idle = supplyAssets − borrowAssets. Borrow pulls real USDC only when idle ≥ ask.
/// Only three protocol-valid ways to raise idle:
///   1) Unmatched SUPPLY (loan token in, borrow not increased by same amount)
///   2) REPAY debt (borrow down, supply stays) — money is in the loans
///   3) Public Allocator reallocateTo (vault moves USDC into market)
///
/// This chassis does (1) and (2). King is the book — repay engineers idle from the matched loan.

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

contract CrownEngineerIdle {
    uint8 internal constant MODE_PROVE = 0; // repay → idle → borrow-to-self → flash close (Landing 0)
    uint8 internal constant MODE_LAND = 1; // repay → idle → borrow-to-Landing; buffer closes flash
    uint8 internal constant MODE_SUPPLY = 2; // unmatched supply → lasting idle (pull USDC from king)

    IMorphoI public immutable morpho;
    IERC20I public immutable usdc;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoI.MarketParams public mp;

    uint256 public lastPeakIdle;
    uint256 public lastLandingCredit;
    uint256 public lastMode;

    error KingOnly();
    error IdleMiss();
    error BufferMiss();
    error RepayFail();

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

    /// @notice CORRECT #2 — engineer idle from the loan book (repay), prove peak ≥ ask, self-borrow closes flash.
    function proveIdleFromLoanBook(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_PROVE, ask));
    }

    /// @notice CORRECT #2 then loan — idle from repay, borrow `ask` to Landing.
    /// @dev Flash-close needs `ask` USDC already on this chassis (buffer). Same dollars — not free print.
    ///      Pull buffer from King first or `deal` in fork. Idle is real; Landing credit is real.
    function idleThenLoanToLanding(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        if (usdc.balanceOf(address(this)) < ask) {
            require(usdc.transferFrom(king, address(this), ask), "BUF");
        }
        if (usdc.balanceOf(address(this)) < ask) revert BufferMiss();
        morpho.flashLoan(address(usdc), ask, abi.encode(MODE_LAND, ask));
    }

    /// @notice CORRECT #1 — unmatched supply. Lasting idle after tx. Pulls `ask` USDC from King.
    function idleFromUnmatchedSupply(uint256 ask) external {
        if (msg.sender != king) revert KingOnly();
        require(usdc.transferFrom(king, address(this), ask), "USDC");
        usdc.approve(address(morpho), ask);
        morpho.accrueInterest(mp);
        morpho.supply(mp, ask, 0, king, "");
        uint256 i = idle();
        lastPeakIdle = i;
        lastMode = MODE_SUPPLY;
        if (i < ask) revert IdleMiss();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint8 mode, uint256 ask) = abi.decode(data, (uint8, uint256));
        require(assets == ask, "AMT");

        morpho.accrueInterest(mp);

        // --- Engineer idle from LOAN BOOK: repay King's borrow ---
        usdc.approve(address(morpho), ask);
        morpho.repay(mp, ask, 0, king, "");

        uint256 peak = idle();
        lastPeakIdle = peak;
        if (peak < ask) revert IdleMiss();

        if (mode == MODE_PROVE) {
            // Borrow back to chassis — proves loan clears on engineered idle; closes flash.
            morpho.borrow(mp, ask, 0, king, address(this));
            lastLandingCredit = 0;
            lastMode = MODE_PROVE;
        } else if (mode == MODE_LAND) {
            // Loan to Landing on engineered idle. Buffer (pre-funded on chassis) closes flash.
            morpho.borrow(mp, ask, 0, king, landing);
            lastLandingCredit = ask;
            lastMode = MODE_LAND;
            // chassis still holds `ask` buffer for Morpho flash pull
        } else {
            revert("MODE");
        }

        if (usdc.balanceOf(address(this)) < ask) revert RepayFail();
        usdc.approve(address(morpho), ask);
    }
}
