// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external;

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

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

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Sovereign Morpho RSS/USDC desk: create market, repayable self-lend open, self-deleverage.
contract MorphoKingDesk is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorpho public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable irm;
    uint256 public immutable lltv;

    address public oracle;
    address public king;
    bytes32 public marketId;
    bool public marketReady;

    IMorpho.MarketParams public marketParams;

    uint256 public hfFloor = 1.05e18;
    uint256 public hfTarget = 1.15e18;

    enum FlashKind {
        None,
        Open,
        Deleverage
    }

    FlashKind private _kind;
    uint256 private _rssAmount;
    uint256 private _repayAssets;

    event MarketCreated(bytes32 indexed id, address oracle, uint256 lltv);
    event SelfLendOpened(uint256 rssCollateral, uint256 usdcDebt);
    event SelfDeleveraged(uint256 debtRepaid, uint256 supplyWithdrawn);

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address irm_,
        uint256 lltv_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        irm = irm_;
        lltv = lltv_;
        king = king_;
    }

    function setKing(address k) external onlyOwner {
        require(k != address(0), "ZERO");
        king = k;
    }

    function setFloors(uint256 floor, uint256 target) external onlyOwner {
        require(floor >= 1e18 && target > floor, "FLOOR");
        hfFloor = floor;
        hfTarget = target;
    }

    function create(address oracle_) external onlyOwner {
        require(!marketReady, "READY");
        oracle = oracle_;
        marketParams = IMorpho.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(rss),
            oracle: oracle_,
            irm: irm,
            lltv: lltv
        });
        morpho.createMarket(marketParams);
        marketId = keccak256(abi.encode(marketParams));
        marketReady = true;
        emit MarketCreated(marketId, oracle_, lltv);
    }

    /// @notice Open repayable self-lend. Prefers buffered debt (caller chooses flash size).
    /// Collateral RSS from King; flash USDC from Morpho (0 fee); supply+collateral+borrow; repay.
    function openSelfLend(uint256 rssAmount, uint256 flashUsdc) external onlyOwner nonReentrant {
        require(marketReady, "MARKET");
        require(rssAmount > 0 && flashUsdc > 0, "ZERO");
        _kind = FlashKind.Open;
        _rssAmount = rssAmount;
        morpho.flashLoan(address(usdc), flashUsdc, bytes(""));
        _kind = FlashKind.None;
        _rssAmount = 0;
    }

    /// @notice Self-deleverage: flash → repay borrow → withdraw supply → repay flash.
    function selfDeleverage(uint256 repayBorrowAssets) external onlyOwner nonReentrant {
        require(marketReady, "MARKET");
        require(repayBorrowAssets > 0, "ZERO");
        _kind = FlashKind.Deleverage;
        _repayAssets = repayBorrowAssets;
        morpho.flashLoan(address(usdc), repayBorrowAssets, bytes(""));
        _kind = FlashKind.None;
        _repayAssets = 0;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        require(msg.sender == address(morpho), "MORPHO");
        if (_kind == FlashKind.Open) {
            _open(assets);
        } else if (_kind == FlashKind.Deleverage) {
            _deleverage(assets);
        } else {
            revert("KIND");
        }
        // Morpho pulls `assets` back via transferFrom
        usdc.safeApprove(address(morpho), assets);
    }

    function _open(uint256 flashUsdc) private {
        uint256 rssAmount = _rssAmount;
        rss.safeTransferFrom(king, address(this), rssAmount);

        usdc.safeApprove(address(morpho), type(uint256).max);
        rss.safeApprove(address(morpho), type(uint256).max);

        // 1) King becomes first lender
        morpho.supply(marketParams, flashUsdc, 0, king, bytes(""));
        // 2) Post RSS collateral
        morpho.supplyCollateral(marketParams, rssAmount, king, bytes(""));
        // 3) Borrow face amount to this desk to repay flash
        morpho.borrow(marketParams, flashUsdc, 0, king, address(this));

        emit SelfLendOpened(rssAmount, flashUsdc);
    }

    function _deleverage(uint256 repayBorrowAssets) private {
        usdc.safeApprove(address(morpho), type(uint256).max);
        // Repay King's debt
        morpho.repay(marketParams, repayBorrowAssets, 0, king, bytes(""));
        // Withdraw own supplied USDC (util freed by repay) to cover flash
        morpho.withdraw(marketParams, repayBorrowAssets, 0, king, address(this));
        emit SelfDeleveraged(repayBorrowAssets, repayBorrowAssets);
    }

    /// @dev View HF ≈ (collateral * price / 1e36 * lltv) / borrowAssets  (1e18 scale)
    function healthFactor(address user) public view returns (uint256) {
        require(marketReady, "MARKET");
        (, uint128 borrowShares, uint128 collateral) = morpho.position(marketId, user);
        if (borrowShares == 0) return type(uint256).max;
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = morpho.market(marketId);
        if (totalBorrowShares == 0) return type(uint256).max;
        uint256 borrowAssets = (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1)
            / uint256(totalBorrowShares);
        // oracle.price()
        (bool ok, bytes memory data) = oracle.staticcall(abi.encodeWithSignature("price()"));
        require(ok && data.length >= 32, "ORACLE");
        uint256 px = abi.decode(data, (uint256));
        uint256 collValue = (uint256(collateral) * px) / 1e36; // in loan-token units
        uint256 maxBorrow = (collValue * lltv) / 1e18;
        return (maxBorrow * 1e18) / borrowAssets;
    }

    function rescue(address token, uint256 amt, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amt);
    }
}
