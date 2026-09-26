// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoMig {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function accrueInterest(MarketParams memory marketParams) external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoMig {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
}

/// @notice Elite peel: migrate king's Morpho USDC supply → yRSS at 100% util.
/// @dev Atomic: Morpho flash → yRSS.deposit (creates idle) → Morpho.withdraw(king supply) → repay flash.
///      Net: vault absorbs the gold rail; king's direct supply falls; debt/coll untouched.
///      Requires: morpho.setAuthorization(this,true), yRSS supplyQueue[0]=PARK, cap room ≥ amount.
contract CrownMigrateYrss is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoMig public immutable morpho;
    IERC20 public immutable usdc;
    IMetaMorphoMig public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoMig.MarketParams public mp;

    bool private _locking;

    event Migrated(uint256 amount, uint256 yrssShares, uint256 kingSupplyLeft);

    error OnlyMorpho();
    error BadAmt();
    error ShortSupply();
    error IdleFail();

    constructor(
        address morpho_,
        address usdc_,
        address yrss_,
        address king_,
        bytes32 marketId_,
        address collat_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoMig(morpho_);
        usdc = IERC20(usdc_);
        yrss = IMetaMorphoMig(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoMig.MarketParams({
            loanToken: usdc_,
            collateralToken: collat_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Migrate `amount` of king's Morpho supply into yRSS (0 = max − $1k dust).
    function migrate(uint256 amount) external onlyOwner nonReentrant {
        morpho.accrueInterest(mp);
        (uint256 supShares,,) = morpho.position(marketId, king);
        (uint128 tsa, uint128 tss,,,,) = morpho.market(marketId);
        if (supShares == 0 || tss == 0) revert ShortSupply();

        uint256 kingAssets = (uint256(supShares) * uint256(tsa)) / uint256(tss);
        // Keep $1k dust so share rounding never zeroes a live borrow book edge-case
        uint256 maxMig = kingAssets > 1_000e6 ? kingAssets - 1_000e6 : 0;
        if (maxMig == 0) revert ShortSupply();

        // Clamp to yRSS remaining market cap (elite: never AllCapsReached)
        (uint184 cap,,) = yrss.config(marketId);
        (uint256 yShares,,) = morpho.position(marketId, address(yrss));
        uint256 yAlloc = tss == 0 ? 0 : (yShares * uint256(tsa)) / uint256(tss);
        uint256 room = uint256(cap) > yAlloc ? uint256(cap) - yAlloc : 0;
        if (room < maxMig) maxMig = room;

        if (amount == 0) amount = maxMig;
        if (amount > maxMig) amount = maxMig;
        if (amount < 1e6) revert BadAmt(); // min $1

        _locking = true;
        morpho.flashLoan(address(usdc), amount, abi.encode(amount));
        _locking = false;

        (uint256 leftShares,,) = morpho.position(marketId, king);
        (uint128 tsa2, uint128 tss2,,,,) = morpho.market(marketId);
        uint256 left = tss2 == 0 ? 0 : (leftShares * uint256(tsa2)) / uint256(tss2);
        emit Migrated(amount, yrssBalance(), left);
    }

    function yrssBalance() public view returns (uint256) {
        // shares held by king — best-effort log helper via staticcall pattern in event path
        (bool ok, bytes memory data) =
            address(yrss).staticcall(abi.encodeWithSignature("balanceOf(address)", king));
        if (!ok || data.length < 32) return 0;
        return abi.decode(data, (uint256));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        uint256 amount = abi.decode(data, (uint256));
        if (assets != amount) revert BadAmt();

        // 1) Deposit flash USDC into yRSS → supply queue[0] (PARK) creates idle
        usdc.safeApprove(address(yrss), assets);
        uint256 shares = yrss.deposit(assets, king);
        if (shares == 0) revert IdleFail();

        // 2) Peel the same size from king's direct Morpho supply (idle funds the withdraw)
        (uint128 tsa,, uint128 tba,,,) = morpho.market(marketId);
        uint256 idle = uint256(tsa) > uint256(tba) ? uint256(tsa) - uint256(tba) : 0;
        if (idle < assets) revert IdleFail();

        morpho.withdraw(mp, assets, 0, king, address(this));

        // 3) Repay Morpho flash (fee = 0)
        usdc.safeApprove(address(morpho), assets);
    }
}
