// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IMorphoSelf {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @title CrownMorphoSelfGuard
/// @notice King-only Morpho deleverage / self-protect. No flash. No multisig.
/// @dev HOT must morpho.setAuthorization(this, true). Pulls USDC from HOT (approve) to repay.
contract CrownMorphoSelfGuard is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoSelf public immutable morpho;
    address public immutable king;

    event Repaid(bytes32 indexed id, uint256 assets);
    event CollPulled(bytes32 indexed id, uint256 assets, address to);

    error KingOnly();
    error BadAmt();

    constructor(address morpho_, address king_, address owner_) Ownable(owner_) {
        require(morpho_ != address(0) && king_ != address(0), "ZERO");
        morpho = IMorphoSelf(morpho_);
        king = king_;
    }

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    /// @notice Repay Morpho debt using USDC already on HOT (must approve this guard).
    function selfRepay(IMorphoSelf.MarketParams calldata mp, uint256 assets) external onlyKing nonReentrant {
        if (assets == 0) revert BadAmt();
        IERC20 usdc = IERC20(mp.loanToken);
        usdc.safeTransferFrom(king, address(this), assets);
        usdc.safeApprove(address(morpho), 0);
        usdc.safeApprove(address(morpho), assets);
        morpho.repay(mp, assets, 0, king, address(0));
        bytes32 id = keccak256(abi.encode(mp));
        emit Repaid(id, assets);
    }

    /// @notice Pull collateral back to king after debt room exists (self-deleverage exit).
    function selfPullColl(IMorphoSelf.MarketParams calldata mp, uint256 assets, address to)
        external
        onlyKing
        nonReentrant
    {
        if (assets == 0) revert BadAmt();
        if (to == address(0)) to = king;
        morpho.withdrawCollateral(mp, assets, king, to);
        emit CollPulled(keccak256(abi.encode(mp)), assets, to);
    }
}
