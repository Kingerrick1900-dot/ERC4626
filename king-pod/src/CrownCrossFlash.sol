// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoX {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

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

/// @notice DeepSeek whale machine: cross-flash USDC → supply on LiquiditySink → borrow to KingVault.
/// @dev Repay rail MUST be funded separately (R1/R3/R4). Pulling the borrow back out of the vault is disabled.
contract CrownCrossFlash is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoX public immutable morpho;
    IERC20 public immutable usdc;
    address public immutable king;
    address public immutable vault;
    /// @dev This contract is the LiquiditySink (supplier ≠ King borrower).
    bytes32 public immutable marketId;
    IMorphoX.MarketParams public marketParams;

    /// @notice USDC sitting here to repay the flash (R1 seed / R3 profits / R4 desk). NOT the vault borrow.
    address public repayRail;

    bool private _flashing;
    uint256 private _flashAmount;

    event CrossFlashTreasury(uint256 seeded, uint256 borrowedToVault, address sink);
    event RepayRailSet(address rail);

    error Zero();
    error Flash();
    error NoRail();
    error NoIdle();

    constructor(
        address morpho_,
        address usdc_,
        address king_,
        address vault_,
        bytes32 marketId_,
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        if (king_ == address(0) || vault_ == address(0)) revert Zero();
        morpho = IMorphoX(morpho_);
        usdc = IERC20(usdc_);
        king = king_;
        vault = vault_;
        marketId = marketId_;
        marketParams = IMorphoX.MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        repayRail = owner_;
    }

    function liquiditySink() external view returns (address) {
        return address(this);
    }

    function setRepayRail(address rail) external onlyOwner {
        if (rail == address(0)) revert Zero();
        repayRail = rail;
        emit RepayRailSet(rail);
    }

    /// @notice Cross-flash S USDC from Morpho global float → sink supplies → King borrows S to vault.
    /// @dev `repayRail` must hold ≥ S USDC and have approved this contract before fire.
    function crossFlashTreasury(uint256 usdcAmount) external onlyOwner nonReentrant {
        if (usdcAmount == 0) revert Zero();
        if (repayRail == address(0)) revert NoRail();
        _flashing = true;
        _flashAmount = usdcAmount;
        morpho.flashLoan(address(usdc), usdcAmount, bytes(""));
        _flashing = false;
        _flashAmount = 0;
    }

    /// @notice No flash — borrow whatever idle USDC is already in the RSS market to vault (oracle headroom).
    function borrowIdleToVault(uint256 usdcAmount) external onlyOwner nonReentrant {
        if (usdcAmount == 0) revert Zero();
        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < usdcAmount) revert NoIdle();
        morpho.borrow(marketParams, usdcAmount, 0, king, vault);
        emit CrossFlashTreasury(0, usdcAmount, address(this));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho) || !_flashing) revert Flash();
        if (assets != _flashAmount) revert Flash();

        // 1) Seed OUR market on THIS sink (supplier ≠ King borrower)
        usdc.safeApprove(address(morpho), assets);
        morpho.supply(marketParams, assets, 0, address(this), bytes(""));

        // 2) Borrow to treasury — HOLD. Vault keeps this USDC.
        morpho.borrow(marketParams, assets, 0, king, vault);

        // 3) Repay flash from repayRail — NEVER from the vault borrow proceeds.
        usdc.safeTransferFrom(repayRail, address(this), assets);
        usdc.safeApprove(address(morpho), assets);

        emit CrossFlashTreasury(assets, assets, address(this));
    }

    function rescue(address token, uint256 amt, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amt);
    }
}
