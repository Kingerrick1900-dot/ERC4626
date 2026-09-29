// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoB {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IPoolEngineerB {
    function seedFromUsdc(uint256 usdcAmt, bool requireBorders) external returns (uint256, uint128);
}

/// @title CrownBorrowSeed
/// @notice Fresh Morpho USDC borrow against HOT RSS collateral → seedFromUsdc. No yRSS. No RSS sell.
/// @dev Requires real market idle (PA / external supply / routed fill). Flash cannot create net USDC.
contract CrownBorrowSeed is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoB public immutable morpho;
    IPoolEngineerB public immutable engineer;
    IERC20 public immutable usdc;
    address public immutable hot;
    bytes32 public immutable marketId;

    event BorrowSeeded(uint256 borrowed, uint256 tokenId, uint128 liquidity);

    error Auth();
    error Bad();
    error NoIdle();

    constructor(
        address morpho_,
        address engineer_,
        address usdc_,
        address hot_,
        bytes32 marketId_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoB(morpho_);
        engineer = IPoolEngineerB(engineer_);
        usdc = IERC20(usdc_);
        hot = hot_;
        marketId = marketId_;
    }

    /// @notice Borrow `amt` USDC onBehalf HOT (must be authorized) and atomically seed Uni LP.
    function borrowAndSeed(uint256 amt) external nonReentrant returns (uint256 tokenId, uint128 liq) {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        if (amt == 0) revert Bad();

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < amt) revert NoIdle();

        IMorphoB.MarketParams memory mp = _mp();
        morpho.borrow(mp, amt, 0, hot, address(this));

        usdc.safeApprove(address(engineer), amt);
        (tokenId, liq) = engineer.seedFromUsdc(amt, true);
        emit BorrowSeeded(amt, tokenId, liq);
    }

    function _mp() internal view returns (IMorphoB.MarketParams memory mp) {
        (address loan, address coll, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(marketId);
        mp = IMorphoB.MarketParams(loan, coll, oracle, irm, lltv);
    }
}
