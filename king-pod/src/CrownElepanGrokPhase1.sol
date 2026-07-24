// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoGrok {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoGrok {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

interface IERC4626Grok {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice Grok Phase 1 loan: Morpho flash → depth seed → borrow → 50/50 Spend/Earn → repay flash.
/// @dev Engineer nail-down (empty market):
///      flash = depth + spend + earn  where depth >= spend+earn (idle covers borrow of spend+earn),
///      BUT repay also needs `depth` back — so hold after routing must be `depth+spend+earn`.
///      Hold after deposit(depth)+borrow(spend+earn) = spend+earn; after send spend+earn = 0.
///      Matched close only when spend=earn=0 and flash=depth=borrow (classic self-seed).
///
///      Grok 50/50 OPEN that closes (Kingdom proven path, then split shares/debt roles):
///      flash = ask ($13M) → yELE.deposit(ask) → borrow(ask) → repay.
///      End: Morpho debt = $13M (loan ON), yELE TVL = $13M.
///      Then route: half yELE shares stay Earn war-chest; redeem path for Spend is bills when idle/buffer allows.
///      Optional liquid split when `liquidSplit` USDC is prefunded on this contract before fire.
contract CrownElepanGrokPhase1 is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant ASK_USDC = 13_000_000e6;
    uint256 public constant MAX_LTV_BPS = 6450; // HF ≥ 1.55 soft-$1
    uint256 public constant MIN_USDC = 100_000e6; // allow tranche fire under $1M when coll-capped

    IMorphoGrok public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable elepan;
    IMetaMorphoGrok public immutable yelepan;
    address public immutable king;
    address public immutable spendReceiver; // KingVault / bills
    address public immutable earnShareReceiver; // vault/loop share holder (Landing or KingVault)
    bytes32 public immutable marketId;
    IMorphoGrok.MarketParams public mp;

    bool private _locking;

    event GrokPhase1Loan(
        uint256 elepanColl, uint256 borrowUsdc, uint256 yeleShares, uint256 spendUsdc, uint256 earnFundedUsdc
    );

    error OnlyMorpho();
    error BadAmt();
    error Ltv();
    error NoIdlePath();

    constructor(
        address morpho_,
        address usdc_,
        address elepan_,
        address yelepan_,
        address king_,
        address spendReceiver_,
        address earnShareReceiver_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        require(spendReceiver_ != address(0) && earnShareReceiver_ != address(0), "RECV");
        morpho = IMorphoGrok(morpho_);
        usdc = IERC20(usdc_);
        elepan = IERC20(elepan_);
        yelepan = IMetaMorphoGrok(yelepan_);
        king = king_;
        spendReceiver = spendReceiver_;
        earnShareReceiver = earnShareReceiver_;
        marketId = marketId_;
        mp = IMorphoGrok.MarketParams({
            loanToken: usdc_,
            collateralToken: elepan_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @param elepanAmount 0 = full hot ELE balance
    /// @param borrowUsdc 0 = $13M
    function phase1(uint256 elepanAmount, uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc == 0) borrowUsdc = ASK_USDC;
        if (borrowUsdc < MIN_USDC) revert BadAmt();
        if (elepanAmount == 0) elepanAmount = elepan.balanceOf(king);

        (, , uint128 existingColl) = morpho.position(marketId, king);
        uint256 totalColl = uint256(existingColl) + elepanAmount;
        if (borrowUsdc * 1e8 > (totalColl * MAX_LTV_BPS * 1e6) / 10_000) revert Ltv();

        if (elepanAmount > 0) {
            elepan.safeTransferFrom(king, address(this), elepanAmount);
            elepan.safeApprove(address(morpho), elepanAmount);
            morpho.supplyCollateral(mp, elepanAmount, king, "");
        }

        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(elepanAmount, borrowUsdc));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();
        (uint256 eleColl, uint256 borrowUsdc) = abi.decode(data, (uint256, uint256));
        if (assets != borrowUsdc) revert BadAmt();

        // Earn leg / depth: seed yELE (vault/loop). Shares → earnShareReceiver.
        usdc.safeApprove(address(yelepan), assets);
        uint256 shares = yelepan.deposit(assets, earnShareReceiver);

        (uint128 supply,, uint128 mBorrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(mBorrow) ? uint256(supply) - uint256(mBorrow) : 0;
        if (idle < assets) revert NoIdlePath();

        // Loan: borrow ask against Elepan; repay flash (REPAY_SOURCE = Morpho.borrow)
        morpho.borrow(mp, assets, 0, king, address(this));
        usdc.safeApprove(address(morpho), assets);

        // Optional liquid Spend leg: any prefunded USDC on this contract → KingVault (50/50 ops funding)
        uint256 spendUsdc = usdc.balanceOf(address(this));
        // after borrow we hold `assets` reserved for flash repay via allowance; Morpho pulls `assets`.
        // Prefunded amount sits above `assets` only if someone transferred USDC in before phase1.
        // Conservatively: do not touch balance needed for repay — Morpho pulls after callback returns.
        // So spend only if balance > assets (prefund).
        if (spendUsdc > assets) {
            spendUsdc = spendUsdc - assets;
            usdc.safeTransfer(spendReceiver, spendUsdc);
        } else {
            spendUsdc = 0;
        }

        emit GrokPhase1Loan(eleColl, borrowUsdc, shares, spendUsdc, borrowUsdc);
    }

    /// @notice Post-loan: move half of earn shares to spendReceiver (50/50 share split). Caller/owner.
    function splitSharesFiftyFifty(address shareToken) external onlyOwner {
        uint256 bal = IERC20(shareToken).balanceOf(address(this));
        if (bal == 0) {
            // pull from earnShareReceiver not possible without approval; no-op if shares already routed
            return;
        }
        uint256 half = bal / 2;
        IERC20(shareToken).safeTransfer(spendReceiver, half);
    }
}
