// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoMA {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory m, uint256 assets, address onBehalf, bytes memory data) external;

    function borrow(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoMA {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function asset() external view returns (address);
}

/// @title CrownMeasuredAccess
/// @notice Part A: eUSD collateral → borrow Morpho idle USDC to HOT.
///         Part B: USDC → ySYNTH.deposit (vault-routed, not around).
/// @dev Lender's USDC only. Reverts if borrowed USDC < minRetain (set 0 to allow deposit-only).
contract CrownMeasuredAccess is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoMA public immutable morpho;
    IMetaMorphoMA public immutable vault;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable hot;

    IMorphoMA.MarketParams public synthMp;
    bytes32 public immutable synthId;

    event AccessCompleted(
        uint256 vaultDeposited, uint256 collateralPosted, uint256 borrowedToHot, uint256 retainedInDestination
    );

    error Auth();
    error Bad();
    error Idle();
    error MinRetain();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address morpho_,
        address vault_,
        address usdc_,
        address eusd_,
        address hot_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoMA(morpho_);
        vault = IMetaMorphoMA(vault_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        hot = hot_;
        if (IMetaMorphoMA(vault_).asset() != usdc_) revert Bad();
        synthMp = IMorphoMA.MarketParams(usdc_, eusd_, oracle_, irm_, lltv_);
        synthId = keccak256(abi.encode(synthMp));
    }

    function marketIdle(bytes32 id) public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(id);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @param usdcToVault Part B deposit into ySYNTH (0 = skip)
    /// @param eusdColl Part A collateral (0 = skip borrow)
    /// @param borrowUsdc target borrow to HOT (capped by idle)
    /// @param minRetain minimum borrowed USDC that must land on HOT
    function access(uint256 usdcToVault, uint256 eusdColl, uint256 borrowUsdc, uint256 minRetain)
        external
        onlyHot
        nonReentrant
    {
        uint256 deposited;
        uint256 posted;
        uint256 borrowed;

        if (usdcToVault > 0) {
            usdc.safeTransferFrom(hot, address(this), usdcToVault);
            usdc.approve(address(vault), usdcToVault);
            vault.deposit(usdcToVault, hot);
            deposited = usdcToVault;
        }

        if (borrowUsdc > 0) {
            if (eusdColl == 0) revert Bad();
            uint256 idle = marketIdle(synthId);
            if (idle == 0) revert Idle();
            if (borrowUsdc > idle) borrowUsdc = idle;
            if (borrowUsdc * 1e12 * 1e18 > eusdColl * synthMp.lltv) revert Bad();

            eusd.safeTransferFrom(hot, address(this), eusdColl);
            eusd.approve(address(morpho), eusdColl);
            morpho.supplyCollateral(synthMp, eusdColl, hot, "");
            posted = eusdColl;
            morpho.borrow(synthMp, borrowUsdc, 0, hot, hot);
            borrowed = borrowUsdc;
        }

        if (borrowed < minRetain) revert MinRetain();
        emit AccessCompleted(deposited, posted, borrowed, borrowed);
    }
}
