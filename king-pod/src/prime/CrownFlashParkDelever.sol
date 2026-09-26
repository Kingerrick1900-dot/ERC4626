// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IMorphoBlue {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256, uint256);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IYrssVault {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function maxWithdraw(address owner) external view returns (uint256);
}

/// @title CrownFlashParkDelever
/// @notice Morpho flash → repay PARK on behalf of King → yRSS.withdraw → repay flash.
/// @dev Identity: ΔUSDC ≈ 0 − gas. This is DELEVER, not a war-chest mint. See freeze sheets.
contract CrownFlashParkDelever is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoBlue public immutable morpho;
    IYrssVault public immutable yrss;
    IERC20 public immutable usdc;
    address public immutable king;

    IMorphoBlue.MarketParams public park;
    bool private _flashing;

    event ParkSet(bytes32 indexed idHint, address oracle, uint256 lltv);
    event Delevered(uint256 flashAmt, uint256 withdrawn, address indexed king);

    error KingOnly();
    error OnlyMorpho();
    error BadAmt();
    error NoWithdraw();

    constructor(
        address morpho_,
        address yrss_,
        address usdc_,
        address king_,
        address owner_,
        address collat_,
        address oracle_,
        address irm_,
        uint256 lltv_
    ) Ownable(owner_) {
        require(
            morpho_ != address(0) && yrss_ != address(0) && usdc_ != address(0) && king_ != address(0),
            "ZERO"
        );
        morpho = IMorphoBlue(morpho_);
        yrss = IYrssVault(yrss_);
        usdc = IERC20(usdc_);
        king = king_;
        park = IMorphoBlue.MarketParams({
            loanToken: usdc_,
            collateralToken: collat_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice King/owner: flash `amt` USDC, repay PARK debt, peel yRSS, repay flash.
    /// @dev King must `yrss.approve(this, type(uint256).max)` before first call.
    function delever(uint256 amt) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (amt == 0) revert BadAmt();
        _flashing = true;
        morpho.flashLoan(address(usdc), amt, abi.encode(amt));
        _flashing = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_flashing) revert OnlyMorpho();

        // 1) Repay King's PARK debt with flashed USDC
        usdc.safeApprove(address(morpho), assets);
        morpho.repay(park, assets, 0, king, "");

        // 2) Withdraw matching USDC from yRSS (King-approved)
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW < assets) revert NoWithdraw();
        uint256 withdrawn = yrss.withdraw(assets, address(this), king);
        // withdrawn is shares; assets received = balance
        uint256 bal = usdc.balanceOf(address(this));
        require(bal >= assets, "SHORT");

        // 3) Repay Morpho flash (fee = 0 on Morpho Blue)
        usdc.safeApprove(address(morpho), assets);

        // Dust to king
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(king, dust);

        emit Delevered(assets, withdrawn, king);
    }
}
