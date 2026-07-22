// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFat {
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

interface IOracleFat {
    function price() external view returns (uint256);
}

/// @notice Whale flash-seed: Morpho FAT WETH/cbBTC -> supply RSS/loan book -> borrow -> repay flash.
contract CrownFatFlashSeed is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant MIN_HF_RAW_WAD = 1.55e18; // collValue/debt >= 1.55
    uint256 public constant HF_ALERT_WAD = 1.60e18; // alert band below 1.60

    IMorphoFat public immutable morpho;
    IERC20 public immutable rss;
    address public immutable king;
    address public immutable landing;

    bool private _flashing;
    address private _loan;
    address private _oracle;
    address private _irm;
    uint256 private _lltv;
    uint256 private _rssColl;
    uint256 private _flashAmt;

    event FatSeeded(
        address indexed loan, bytes32 marketId, uint256 flashAmt, uint256 rssColl, uint256 supplyAssets, uint256 borrowAssets, uint256 hfRawWad
    );
    event HfAlert(address indexed loan, uint256 hfRawWad);

    error OnlyMorpho();
    error BadAmt();
    error Undercollateral();
    error SeedMiss();
    error HfBelowMin();

    constructor(address morpho_, address rss_, address king_, address landing_, address owner_) Ownable(owner_) {
        morpho = IMorphoFat(morpho_);
        rss = IERC20(rss_);
        king = king_;
        landing = landing_;
    }

    /// @notice Atomic flash seed from Morpho inventory into RSS/loan market.
    /// @dev Requires post-action HF_raw = collValue/debt >= 1.55 (King guard).
    function flashSeed(address loan, address oracle, address irm, uint256 lltv, uint256 flashAmt, uint256 rssColl)
        external
        onlyOwner
        nonReentrant
    {
        if (flashAmt == 0 || rssColl == 0 || loan == address(0) || oracle == address(0)) revert BadAmt();

        uint256 px = IOracleFat(oracle).price();
        // HF_raw = (rssColl * px / 1e36) / flashAmt >= 1.55
        uint256 collLoan = rssColl * px / 1e36;
        uint256 hfRaw = collLoan * 1e18 / flashAmt;
        if (hfRaw < MIN_HF_RAW_WAD) revert HfBelowMin();

        // Also must clear Morpho LLTV (max borrow)
        uint256 maxBorrow = collLoan * lltv / 1e18;
        if (maxBorrow < flashAmt) revert Undercollateral();

        rss.safeTransferFrom(king, address(this), rssColl);

        _loan = loan;
        _oracle = oracle;
        _irm = irm;
        _lltv = lltv;
        _rssColl = rssColl;
        _flashAmt = flashAmt;
        _flashing = true;
        morpho.flashLoan(loan, flashAmt, abi.encode(flashAmt));
        _flashing = false;

        bytes32 id = _id(loan, oracle, irm, lltv);
        (uint128 supply,, uint128 borrow,,,) = morpho.market(id);
        if (uint256(supply) < flashAmt || uint256(borrow) < flashAmt) revert SeedMiss();

        if (hfRaw < HF_ALERT_WAD) emit HfAlert(loan, hfRaw);
        emit FatSeeded(loan, id, flashAmt, rssColl, supply, borrow, hfRaw);

        _loan = address(0);
        _oracle = address(0);
        _irm = address(0);
        _lltv = 0;
        _rssColl = 0;
        _flashAmt = 0;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_flashing) revert OnlyMorpho();
        uint256 flashAmt = abi.decode(data, (uint256));
        if (assets != flashAmt || assets != _flashAmt) revert BadAmt();

        IMorphoFat.MarketParams memory mp = IMorphoFat.MarketParams({
            loanToken: _loan,
            collateralToken: address(rss),
            oracle: _oracle,
            irm: _irm,
            lltv: _lltv
        });

        IERC20 loanTok = IERC20(_loan);
        loanTok.safeApprove(address(morpho), assets);
        morpho.supply(mp, assets, 0, king, "");

        rss.safeApprove(address(morpho), _rssColl);
        morpho.supplyCollateral(mp, _rssColl, king, "");

        morpho.borrow(mp, assets, 0, king, address(this));

        if (loanTok.balanceOf(address(this)) < assets) revert SeedMiss();
        loanTok.safeApprove(address(morpho), assets);
    }

    function rescue(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt);
    }

    function _id(address loan, address oracle, address irm, uint256 lltv) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                IMorphoFat.MarketParams({
                    loanToken: loan,
                    collateralToken: address(rss),
                    oracle: oracle,
                    irm: irm,
                    lltv: lltv
                })
            )
        );
    }
}
