// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoD {
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
    function withdraw(
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

interface IMetaMorphoD {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
}

interface IPoolEngineer {
    function seedFromUsdc(uint256 usdcAmt, bool requireBorders) external returns (uint256, uint128);
}

/// @title CrownDeallocSeed
/// @notice Flash-supply Morpho idle → yRSS.withdraw → seedFromUsdc → repay. No beg. No RSS sell.
/// @dev At 100% util, external flash supply creates withdrawable room; vault exits into seed.
contract CrownDeallocSeed is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoD public immutable morpho;
    IMetaMorphoD public immutable yrss;
    IPoolEngineer public immutable engineer;
    IERC20 public immutable usdc;
    address public immutable hot;
    bytes32 public immutable marketId;

    event DeallocSeeded(uint256 seeded, uint256 maxWithdrawAfter);

    error OnlyMorpho();
    error Bad();

    constructor(
        address morpho_,
        address yrss_,
        address engineer_,
        address usdc_,
        address hot_,
        bytes32 marketId_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoD(morpho_);
        yrss = IMetaMorphoD(yrss_);
        engineer = IPoolEngineer(engineer_);
        usdc = IERC20(usdc_);
        hot = hot_;
        marketId = marketId_;
    }

    /// @notice Free `amt` USDC from yRSS via 2× flash bridge, seed Uni LP atomically.
    function deallocAndSeed(uint256 amt) external nonReentrant {
        if (msg.sender != owner && msg.sender != hot) revert Bad();
        if (amt == 0) revert Bad();
        morpho.flashLoan(address(usdc), amt * 2, abi.encode(amt));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        uint256 amt = abi.decode(data, (uint256));
        if (assets != amt * 2) revert Bad();

        IMorphoD.MarketParams memory mp = _mp();

        // Create `amt` withdrawable liquidity on the vault's allocated market
        usdc.safeApprove(address(morpho), amt);
        morpho.supply(mp, amt, 0, address(this), bytes(""));

        // Vault can now exit `amt` (HOT approved shares to this contract)
        if (yrss.maxWithdraw(hot) < amt) revert Bad();
        yrss.withdraw(amt, address(this), hot);

        // Pull bridge supply back
        morpho.withdraw(mp, amt, 0, address(this), address(this));

        // Seed from vault margin
        usdc.safeApprove(address(engineer), amt);
        engineer.seedFromUsdc(amt, true);

        // Repay 2× flash
        usdc.safeApprove(address(morpho), assets);
        emit DeallocSeeded(amt, yrss.maxWithdraw(hot));
    }

    function _mp() internal view returns (IMorphoD.MarketParams memory mp) {
        (address loan, address coll, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(marketId);
        mp = IMorphoD.MarketParams(loan, coll, oracle, irm, lltv);
    }
}
