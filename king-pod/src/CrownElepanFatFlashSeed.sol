// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoElepan {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IOracleElepan {
    function price() external view returns (uint256);
}

/// @notice Flash-seed Elepan/loan Morpho markets from Morpho inventory (WETH/cbBTC).
/// @dev Implements Morpho `IMorphoFlashLoanCallback`. Inside `onMorphoFlashLoan`:
///      supply loan → supplyCollateral Elepan → borrow → approve repayment.
///      Any failure reverts the whole flash (nothing sticks). Matched books; HF_raw ≥ 1.55.
contract CrownElepanFatFlashSeed is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant MIN_HF_RAW_WAD = 1.55e18;
    uint256 public constant HF_ALERT_WAD = 1.60e18;

    IMorphoElepan public immutable morpho;
    IERC20 public immutable elepan;
    address public immutable king;

    bool private _flashing;
    address private _loan;
    address private _oracle;
    address private _irm;
    uint256 private _lltv;
    uint256 private _coll;
    uint256 private _flashAmt;

    event FatSeeded(
        address indexed loan,
        bytes32 marketId,
        uint256 flashAmt,
        uint256 elepanColl,
        uint256 supplyAssets,
        uint256 borrowAssets,
        uint256 hfRawWad
    );
    event HfAlert(address indexed loan, uint256 hfRawWad);

    error OnlyMorpho();
    error BadAmt();
    error Undercollateral();
    error SeedMiss();
    error HfBelowMin();

    constructor(address morpho_, address elepan_, address king_, address owner_) Ownable(owner_) {
        morpho = IMorphoElepan(morpho_);
        elepan = IERC20(elepan_);
        king = king_;
    }

    function flashSeed(address loan, address oracle, address irm, uint256 lltv, uint256 flashAmt, uint256 elepanColl)
        external
        onlyOwner
        nonReentrant
    {
        if (flashAmt == 0 || elepanColl == 0 || loan == address(0) || oracle == address(0)) revert BadAmt();

        uint256 px = IOracleElepan(oracle).price();
        uint256 collLoan = elepanColl * px / 1e36;
        uint256 hfRaw = collLoan * 1e18 / flashAmt;
        if (hfRaw < MIN_HF_RAW_WAD) revert HfBelowMin();

        uint256 maxBorrow = collLoan * lltv / 1e18;
        if (maxBorrow < flashAmt) revert Undercollateral();

        elepan.safeTransferFrom(king, address(this), elepanColl);

        _loan = loan;
        _oracle = oracle;
        _irm = irm;
        _lltv = lltv;
        _coll = elepanColl;
        _flashAmt = flashAmt;
        _flashing = true;
        morpho.flashLoan(loan, flashAmt, abi.encode(flashAmt));
        _flashing = false;

        bytes32 id = keccak256(
            abi.encode(
                IMorphoElepan.MarketParams({
                    loanToken: loan, collateralToken: address(elepan), oracle: oracle, irm: irm, lltv: lltv
                })
            )
        );
        (uint128 supply,, uint128 borrow,,,) = morpho.market(id);
        if (uint256(supply) < flashAmt || uint256(borrow) < flashAmt) revert SeedMiss();

        if (hfRaw < HF_ALERT_WAD) emit HfAlert(loan, hfRaw);
        emit FatSeeded(loan, id, flashAmt, elepanColl, supply, borrow, hfRaw);

        _loan = address(0);
        _oracle = address(0);
        _irm = address(0);
        _lltv = 0;
        _coll = 0;
        _flashAmt = 0;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_flashing) revert OnlyMorpho();
        uint256 flashAmt = abi.decode(data, (uint256));
        if (assets != flashAmt || assets != _flashAmt) revert BadAmt();

        IMorphoElepan.MarketParams memory mp = IMorphoElepan.MarketParams({
            loanToken: _loan,
            collateralToken: address(elepan),
            oracle: _oracle,
            irm: _irm,
            lltv: _lltv
        });

        IERC20 loanTok = IERC20(_loan);
        loanTok.approve(address(morpho), assets);
        morpho.supply(mp, assets, 0, king, "");

        elepan.approve(address(morpho), _coll);
        morpho.supplyCollateral(mp, _coll, king, "");

        morpho.borrow(mp, assets, 0, king, address(this));

        if (loanTok.balanceOf(address(this)) < assets) revert SeedMiss();
        loanTok.approve(address(morpho), assets);
    }

    function rescue(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
