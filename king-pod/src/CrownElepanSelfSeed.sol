// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoEle {
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

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoEle {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice Bootstrap yELEPAN-USDC via Morpho flash (protocol USDC), not market idle.
/// @dev Same machine as CrownSelfSeedNine:
///      post Elepan coll → flash USDC (Morpho inventory) → deposit yELEPAN → borrow → repay flash.
///      REPAY_SOURCE = Morpho.borrow(onBehalf king) against posted Elepan + vault-supplied depth.
///      End: king holds yELEPAN shares (war chest), Morpho debt ≈ flash, wallet USDC unchanged.
contract CrownElepanSelfSeed is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant ASK_USDC = 9_000_000e6;
    uint256 public constant MAX_LTV_BPS = 7000; // 70% vs soft $1 Elepan (8dp)
    uint256 public constant MIN_USDC = 1_000_000e6;

    IMorphoEle public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable elepan;
    IMetaMorphoEle public immutable yelepan;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoEle.MarketParams public mp;

    bool private _locking;

    event ElepanSelfSeeded(uint256 elepanColl, uint256 usdcToVault, uint256 borrowUsdc, uint256 yeleShares);

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
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoEle(morpho_);
        usdc = IERC20(usdc_);
        elepan = IERC20(elepan_);
        yelepan = IMetaMorphoEle(yelepan_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoEle.MarketParams({
            loanToken: usdc_,
            collateralToken: elepan_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @param elepanAmount Elepan to post (8dp; 0 = full king wallet)
    /// @param borrowUsdc USDC flash/seed size (6dp; 0 = ASK_USDC)
    function selfSeed(uint256 elepanAmount, uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc == 0) borrowUsdc = ASK_USDC;
        if (borrowUsdc < MIN_USDC) revert BadAmt();

        if (elepanAmount == 0) elepanAmount = elepan.balanceOf(king);

        // soft $1: borrowUsdc/1e6 <= 0.70 * elepanAmount/1e8
        // borrowUsdc * 1e8 <= elepanAmount * 0.70 * 1e6
        if (borrowUsdc * 1e8 > (elepanAmount * MAX_LTV_BPS * 1e6) / 10_000) revert Ltv();

        elepan.safeTransferFrom(king, address(this), elepanAmount);
        elepan.safeApprove(address(morpho), elepanAmount);
        morpho.supplyCollateral(mp, elepanAmount, king, "");

        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(elepanAmount, borrowUsdc));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 eleColl, uint256 borrowUsdc) = abi.decode(data, (uint256, uint256));
        if (assets != borrowUsdc) revert BadAmt();

        usdc.safeApprove(address(yelepan), assets);
        uint256 shares = yelepan.deposit(assets, king);

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert NoIdlePath();

        morpho.borrow(mp, assets, 0, king, address(this));
        usdc.safeApprove(address(morpho), assets);

        emit ElepanSelfSeeded(eleColl, assets, assets, shares);
    }
}
