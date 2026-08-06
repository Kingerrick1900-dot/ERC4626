// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownSeamlessMission
/// @notice One protocol, copied to the letter: **Seamless LeverageRouter**.
///
/// Seamless settle law (deposit):
///   1. Pull equity collateral from sender (`collateralFromSender`)
///   2. Morpho `flashLoan` debt asset
///   3. Work leg (here: post equity + manufacture idle via repay on King's book)
///   4. Debt sitting on the ROUTER repays the flash — that IS close capital
///   5. Any surplus debt above the flash amount → sender (we send → Landing)
///
/// Ref: seamless-protocol/leverage-tokens `LeverageRouter._depositAndRepayMorphoFlashLoan`
///   "Approve morpho to transfer debt assets to repay the flash loan"
///   "Any surplus debt assets after repaying the flash loan are given to the sender"
///
/// No prefunded USDC on hot. Close = borrow-to-router (or repay-leg USDC still on router).
/// Landing payout = Seamless surplus only (debtOnRouter − flashAmount). On a 100% util
/// self-matched book, surplus is 0 until foreign idle / PA injects lasting USDC.

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
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

contract CrownSeamlessMission {
    IMorphoS public immutable morpho;
    IERC20S public immutable usdc;
    IERC20S public immutable rss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoS.MarketParams public mp;

    uint256 public lastFlash;
    uint256 public lastDebtOnRouter;
    uint256 public lastSurplusToLanding;
    uint256 public lastPeakIdle;
    uint256 public lastEquityRss;
    bool public lastClosed;

    event SeamlessMission(
        uint256 flash,
        uint256 debtOnRouter,
        uint256 surplusToLanding,
        uint256 peakIdle,
        uint256 equityRss,
        bool closed
    );

    error KingOnly();
    error IdleMiss();
    error CloseFail();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        address landing_,
        bytes32 marketId_
    ) {
        morpho = IMorphoS(morpho_);
        usdc = IERC20S(usdc_);
        rss = IERC20S(rss_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoS(morpho_).idToMarketParams(marketId_);
        mp = IMorphoS.MarketParams(loan, coll, oracle, irm, lltv);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Seamless deposit-shaped mission. `equityRss` = collateralFromSender (0 allowed).
    /// @dev Flash closes from debt on this router. Surplus USDC (if any) → Landing.
    function seamlessClose(uint256 flashAmount, uint256 equityRss) external {
        if (msg.sender != king) revert KingOnly();
        if (equityRss > 0) {
            require(rss.transferFrom(king, address(this), equityRss), "RSS");
        }
        morpho.flashLoan(address(usdc), flashAmount, abi.encode(flashAmount, equityRss));
    }

    /// @notice Same settle law, explicit Landing ask: borrow flashAmount (close) + try surplus >= want.
    /// @dev Reverts CloseFail if router cannot cover flash after surplus push — Seamless behavior.
    function seamlessLand(uint256 flashAmount, uint256 wantLanding, uint256 equityRss) external {
        if (msg.sender != king) revert KingOnly();
        if (equityRss > 0) {
            require(rss.transferFrom(king, address(this), equityRss), "RSS");
        }
        morpho.flashLoan(address(usdc), flashAmount, abi.encode(flashAmount, equityRss, wantLanding));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");

        uint256 flashAmount;
        uint256 equityRss;
        uint256 wantLanding;
        if (data.length == 64) {
            (flashAmount, equityRss) = abi.decode(data, (uint256, uint256));
            wantLanding = 0;
        } else {
            (flashAmount, equityRss, wantLanding) = abi.decode(data, (uint256, uint256, uint256));
        }
        require(assets == flashAmount, "AMT");

        morpho.accrueInterest(mp);

        // Seamless step: equity collateral from sender posted onto the position
        if (equityRss > 0) {
            rss.approve(address(morpho), equityRss);
            morpho.supplyCollateral(mp, equityRss, king, "");
        }

        // On King's self-matched book: manufacture idle with the flash (repay), then borrow
        // debt TO THIS ROUTER — Seamless close capital = debt on router.
        usdc.approve(address(morpho), flashAmount);
        morpho.repay(mp, flashAmount, 0, king, "");

        uint256 peak = idle();
        if (peak < flashAmount) revert IdleMiss();
        lastPeakIdle = peak;

        // Borrow flashAmount to router (exact flash close). If idle allows and wantLanding > 0,
        // borrow surplus in the same leg — Seamless surplus-to-sender.
        uint256 borrowTotal = flashAmount + wantLanding;
        if (borrowTotal > peak) {
            // Take everything idle allows; surplus may be < want (Seamless still closes if >= flash)
            borrowTotal = peak;
        }
        morpho.borrow(mp, borrowTotal, 0, king, address(this));

        uint256 debtOnRouter = usdc.balanceOf(address(this));
        if (debtOnRouter < flashAmount) revert CloseFail();

        uint256 surplus = debtOnRouter - flashAmount;
        if (surplus > 0) {
            // Seamless: surplus debt assets → sender. Mission sender credit = Landing.
            require(usdc.transfer(landing, surplus), "LAND");
        }

        lastFlash = flashAmount;
        lastDebtOnRouter = debtOnRouter;
        lastSurplusToLanding = surplus;
        lastEquityRss = equityRss;
        lastClosed = true;

        // Seamless: approve Morpho to pull flashAmount (close). Leftover must be 0 after surplus push.
        usdc.approve(address(morpho), flashAmount);
        emit SeamlessMission(flashAmount, debtOnRouter, surplus, peak, equityRss, true);
    }
}
