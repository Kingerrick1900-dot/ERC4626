// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoEle2 {
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

interface IMorphoFlashLoanCallback2 {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoEle2 {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice V2: same flash bootstrap, vault shares minted to immutable `shareReceiver` (Landing).
contract CrownElepanSelfSeedV2 is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback2 {
    using SafeTransfer for IERC20;

    uint256 public constant MAX_LTV_BPS = 7000;
    uint256 public constant MIN_USDC = 1_000_000e6;

    IMorphoEle2 public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable elepan;
    IMetaMorphoEle2 public immutable yelepan;
    address public immutable king;
    address public immutable shareReceiver;
    bytes32 public immutable marketId;
    IMorphoEle2.MarketParams public mp;

    bool private _locking;

    event ElepanSelfSeeded(uint256 elepanColl, uint256 usdcToVault, uint256 borrowUsdc, uint256 yeleShares, address receiver);

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
        address shareReceiver_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        require(shareReceiver_ != address(0), "RECEIVER");
        morpho = IMorphoEle2(morpho_);
        usdc = IERC20(usdc_);
        elepan = IERC20(elepan_);
        yelepan = IMetaMorphoEle2(yelepan_);
        king = king_;
        shareReceiver = shareReceiver_;
        marketId = marketId_;
        mp = IMorphoEle2.MarketParams({
            loanToken: usdc_,
            collateralToken: elepan_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    function selfSeed(uint256 elepanAmount, uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc < MIN_USDC) revert BadAmt();
        if (elepanAmount == 0) elepanAmount = elepan.balanceOf(king);
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
        uint256 shares = yelepan.deposit(assets, shareReceiver);

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert NoIdlePath();

        morpho.borrow(mp, assets, 0, king, address(this));
        usdc.safeApprove(address(morpho), assets);

        emit ElepanSelfSeeded(eleColl, assets, assets, shares, shareReceiver);
    }
}
