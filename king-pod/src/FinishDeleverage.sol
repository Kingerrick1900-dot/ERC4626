// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IYrssF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function reallocate(MarketAllocation[] calldata allocations) external;
    function skim(address token) external;
    function withdrawQueue(uint256) external view returns (bytes32);
    function withdrawQueueLength() external view returns (uint256);
}

/// @notice Finish freer dust: flash → repay hot → free coll → pull ONLY liquid yRSS supply → skim → repay flash.
contract FinishDeleverage is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoF public immutable morpho;
    IERC20 public immutable usdc;
    IYrssF public immutable yrss;
    address public immutable borrower;
    address public immutable receiver;
    bytes32 public immutable marketId;
    IMorphoF.MarketParams public mp;
    bool private _locking;

    error OnlyMorpho();
    error Short();
    error NoDebt();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address yrss_,
        address borrower_,
        address receiver_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoF(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssF(yrss_);
        borrower = borrower_;
        receiver = receiver_;
        marketId = marketId_;
        mp = IMorphoF.MarketParams(usdc_, rss_, oracle_, irm_, lltv_);
    }

    function execute() external onlyOwner nonReentrant {
        morpho.accrueInterest(mp);
        (, uint128 bor, uint128 coll) = morpho.position(marketId, borrower);
        if (bor == 0 && coll == 0) return;
        if (bor == 0) {
            morpho.withdrawCollateral(mp, coll, borrower, receiver);
            return;
        }
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        uint256 flashAmt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
        _locking = true;
        morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(bor), uint256(coll)));
        _locking = false;
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(receiver, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();
        (uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256));
        usdc.approve(address(morpho), type(uint256).max);

        if (borShares > 0) morpho.repay(mp, 0, borShares, borrower, "");
        if (coll > 0) morpho.withdrawCollateral(mp, coll, borrower, receiver);

        // Only drain THIS market (now liquid after repay). Do not touch 100% util markets.
        IYrssF.MarketAllocation[] memory allocs = new IYrssF.MarketAllocation[](1);
        allocs[0] = IYrssF.MarketAllocation({
            marketParams: IYrssF.MarketParams(mp.loanToken, mp.collateralToken, mp.oracle, mp.irm, mp.lltv),
            assets: 0
        });
        yrss.reallocate(allocs);
        yrss.skim(address(usdc));

        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) {
            uint256 still = assets - have;
            uint256 bal = usdc.balanceOf(borrower);
            uint256 take = bal < still ? bal : still;
            if (take > 0) usdc.safeTransferFrom(borrower, address(this), take);
            have = usdc.balanceOf(address(this));
        }
        if (have < assets) revert Short();
        usdc.approve(address(morpho), assets);
    }
}
