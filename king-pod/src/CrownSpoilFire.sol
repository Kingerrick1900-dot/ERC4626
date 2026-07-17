// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoSpoil {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

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

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IPublicAllocatorSpoil {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;

    function fee(address vault) external view returns (uint256);
}

/// @notice Spoil of war: PA pull USDC into RSS market → borrow to KingVault against live King collateral.
/// @dev King must `morpho.setAuthorization(spoil, true)` once. No new RSS required if HF headroom exists.
contract CrownSpoilFire is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoSpoil public immutable morpho;
    IPublicAllocatorSpoil public immutable pa;
    address public immutable king;
    address public immutable vault;
    bytes32 public immutable marketId;
    IMorphoSpoil.MarketParams public rssMarket;

    event SpoilTaken(address indexed paVault, uint256 borrowedUsdc, address indexed to);

    error Zero();
    error NoIdle();
    error BadVault();

    constructor(
        address morpho_,
        address pa_,
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
        morpho = IMorphoSpoil(morpho_);
        pa = IPublicAllocatorSpoil(pa_);
        king = king_;
        vault = vault_;
        marketId = marketId_;
        rssMarket = IMorphoSpoil.MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Pull via PA (optional empty withdrawals if idle already on market), then borrow to vault.
    function fire(
        address paVault,
        IPublicAllocatorSpoil.Withdrawal[] calldata withdrawals,
        uint256 borrowUsdc
    ) external payable onlyOwner nonReentrant {
        if (borrowUsdc == 0) revert Zero();

        if (withdrawals.length > 0) {
            if (paVault == address(0)) revert BadVault();
            uint256 fee = pa.fee(paVault);
            pa.reallocateTo{value: fee}(
                paVault,
                withdrawals,
                IPublicAllocatorSpoil.MarketParams({
                    loanToken: rssMarket.loanToken,
                    collateralToken: rssMarket.collateralToken,
                    oracle: rssMarket.oracle,
                    irm: rssMarket.irm,
                    lltv: rssMarket.lltv
                })
            );
        }

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < borrowUsdc) revert NoIdle();

        morpho.borrow(rssMarket, borrowUsdc, 0, king, vault);
        emit SpoilTaken(paVault, borrowUsdc, vault);
    }

    function rescue(address token, uint256 amt, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amt);
    }

    receive() external payable {}
}
