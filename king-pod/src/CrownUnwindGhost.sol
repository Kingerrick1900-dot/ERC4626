// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoU {
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

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

interface IMorphoFlashLoanCallbackU {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @title CrownUnwindGhost
/// @notice Close CrownLoopNative ghost positions: flash → repay borrow → withdraw supply → repay flash.
/// @dev Does NOT mint free USDC. Flash closes. Recovers eUSD collateral when borrow is fully cleared.
///      King Morpho.setAuthorization(this, true) required.
contract CrownUnwindGhost is Ownable, ReentrancyGuard, IMorphoFlashLoanCallbackU {
    using SafeTransfer for IERC20;

    IMorphoU public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoU.MarketParams public mp;

    bool private _locking;
    uint256 public totalRepaid;
    uint256 public totalWithdrawn;
    uint256 public totalCollFreed;
    uint256 public fires;

    event Unwound(uint256 repaid, uint256 withdrawn, uint256 collFreed, uint256 fireId);

    error OnlyMorpho();
    error BadAmt();
    error Auth();
    error NoDebt();

    modifier onlyKing() {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address eusd_,
        address king_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoU(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        king = king_;
        mp = IMorphoU.MarketParams({
            loanToken: usdc_,
            collateralToken: eusd_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        marketId = keccak256(abi.encode(mp));
    }

    function borrowAssetsOf(address user) public view returns (uint256) {
        (, uint128 borrowShares,) = morpho.position(marketId, user);
        if (borrowShares == 0) return 0;
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(marketId);
        if (totalBorrowShares == 0) return 0;
        // Morpho mulDivUp-style: shares * assets / shares rounded up
        return (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1)
            / uint256(totalBorrowShares);
    }

    function supplyAssetsOf(address user) public view returns (uint256) {
        (uint256 supplyShares,,) = morpho.position(marketId, user);
        if (supplyShares == 0) return 0;
        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = morpho.market(marketId);
        if (totalSupplyShares == 0) return 0;
        return (uint256(supplyShares) * uint256(totalSupplyAssets)) / uint256(totalSupplyShares);
    }

    /// @notice Unwind up to `flashUsdc` of ghost borrow/supply. Pass type(uint256).max for full close.
    function unwind(uint256 flashUsdc) external onlyKing nonReentrant {
        uint256 debt = borrowAssetsOf(king);
        if (debt == 0) revert NoDebt();
        uint256 amt = flashUsdc;
        if (amt > debt) amt = debt;
        if (amt < 1e6) revert BadAmt();

        _locking = true;
        morpho.flashLoan(address(usdc), amt, abi.encode(amt));
        _locking = false;

        // Free eUSD collateral only when borrow fully cleared
        uint256 freed;
        (, uint128 borrowShares, uint128 coll) = morpho.position(marketId, king);
        if (borrowShares == 0 && coll > 0) {
            morpho.withdrawCollateral(mp, coll, king, king);
            freed = coll;
            totalCollFreed += freed;
        }

        unchecked {
            ++fires;
        }
        emit Unwound(totalRepaid, totalWithdrawn, freed, fires);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        uint256 amt = abi.decode(data, (uint256));
        if (assets != amt) revert BadAmt();

        // 1) Repay king's borrow with flashed USDC
        usdc.approve(address(morpho), assets);
        (uint256 repaidAssets,) = morpho.repay(mp, assets, 0, king, "");
        totalRepaid += repaidAssets;

        // 2) Withdraw matching supply to this contract (closes ghost depth)
        uint256 supplyBal = supplyAssetsOf(king);
        uint256 pull = assets;
        if (pull > supplyBal) pull = supplyBal;
        (uint256 withdrawn,) = morpho.withdraw(mp, pull, 0, king, address(this));
        totalWithdrawn += withdrawn;

        // 3) Repay flash — any dust stays on this contract for king skim
        usdc.approve(address(morpho), assets);
    }

    function skimUsdc() external onlyKing {
        uint256 bal = usdc.balanceOf(address(this));
        if (bal > 0) usdc.safeTransfer(king, bal);
    }

    function skimEusd() external onlyKing {
        uint256 bal = eusd.balanceOf(address(this));
        if (bal > 0) eusd.safeTransfer(king, bal);
    }
}
