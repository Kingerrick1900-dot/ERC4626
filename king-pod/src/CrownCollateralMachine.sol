// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoCM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

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

interface IZkAdvanceCM {
    function advance(uint256 usdcAmt) external;
}

interface IAeroRouterCM {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/// @notice Collateral-only Landing fill. LAW: USDC hits cold Landing or full tx reverts.
/// @dev Flash is a lever — not a printer. Named repay = Aero.swap(RSS→USDC) or spot Morpho borrow.
contract CrownCollateralMachine is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint8 public constant MODE_FLASH_ADVANCE = 2;

    IMorphoCM public immutable morpho;
    IAeroRouterCM public immutable aero;
    address public immutable aeroFactory;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IZkAdvanceCM public immutable advance;
    address public immutable landing;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoCM.MarketParams public mp;

    bool private _flashing;
    uint8 private _mode;
    uint256 private _rssSell;
    uint256 private _usdcMinOut;
    uint256 private _landBefore;

    event BorrowToLanding(uint256 rssColl, uint256 usdcOut, address landing);
    event FlashAdvanceToLanding(uint256 flashUsdc, uint256 rssSold, uint256 usdcRepaid, uint256 landingGain);

    error OnlyMorpho();
    error BadAmt();
    error BadMode();
    error NoIdle();
    error LandingMiss(); // cold wallet did not receive — whole tx dead
    error RepayShort();

    constructor(
        address morpho_,
        address aero_,
        address aeroFactory_,
        address usdc_,
        address rss_,
        address advance_,
        address landing_,
        address king_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        if (landing_ == address(0)) revert BadAmt();
        morpho = IMorphoCM(morpho_);
        aero = IAeroRouterCM(aero_);
        aeroFactory = aeroFactory_;
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        advance = IZkAdvanceCM(advance_);
        landing = landing_;
        king = king_;
        marketId = marketId_;
        mp = IMorphoCM.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Spot borrow against RSS → Landing only. No idle / no cold credit → revert.
    function borrowToLanding(uint256 rssColl, uint256 usdcAmt) external onlyOwner nonReentrant {
        if (rssColl == 0 || usdcAmt == 0) revert BadAmt();

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < usdcAmt) revert NoIdle();

        rss.safeTransferFrom(king, address(this), rssColl);
        rss.safeApprove(address(morpho), rssColl);
        morpho.supplyCollateral(mp, rssColl, king, "");

        uint256 before = usdc.balanceOf(landing);
        morpho.borrow(mp, usdcAmt, 0, king, landing);
        _requireCold(before, usdcAmt);

        emit BorrowToLanding(rssColl, usdcAmt, landing);
    }

    /// @notice Flash → ZK Advance to Landing → sell RSS to repay. Cold miss or repay miss → full revert.
    /// @dev REPAY_SOURCE = Aero.swap(RSS→USDC). No pocket USDC.
    function flashAdvanceToLanding(uint256 usdcAmt, uint256 rssSell, uint256 usdcMinOut)
        external
        onlyOwner
        nonReentrant
    {
        if (usdcAmt == 0 || rssSell == 0) revert BadAmt();
        if (usdcMinOut < usdcAmt) revert BadAmt();

        rss.safeTransferFrom(king, address(this), rssSell);

        _mode = MODE_FLASH_ADVANCE;
        _rssSell = rssSell;
        _usdcMinOut = usdcMinOut;
        _landBefore = usdc.balanceOf(landing);
        _flashing = true;
        morpho.flashLoan(address(usdc), usdcAmt, abi.encode(usdcAmt));
        _flashing = false;

        // LAW: after flash closes, cold must hold the fill — else revert (undoes entire tx)
        _requireCold(_landBefore, usdcAmt);

        emit FlashAdvanceToLanding(usdcAmt, rssSell, usdcAmt, usdcAmt);

        _mode = 0;
        _rssSell = 0;
        _usdcMinOut = 0;
        _landBefore = 0;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_flashing) revert OnlyMorpho();
        uint256 usdcAmt = abi.decode(data, (uint256));
        if (assets != usdcAmt) revert BadAmt();
        if (_mode != MODE_FLASH_ADVANCE) revert BadMode();

        // Temporary USDC → Advance → Landing; receive kUSD here
        usdc.safeApprove(address(advance), assets);
        advance.advance(assets);

        // Mid-callback cold check — fail early; still atomic with outer check
        _requireCold(_landBefore, assets);

        // REPAY_SOURCE: sell RSS → USDC, repay Morpho flash
        rss.safeApprove(address(aero), _rssSell);
        IAeroRouterCM.Route[] memory routes = new IAeroRouterCM.Route[](1);
        routes[0] = IAeroRouterCM.Route({from: address(rss), to: address(usdc), stable: false, factory: aeroFactory});
        aero.swapExactTokensForTokens(_rssSell, _usdcMinOut, routes, address(this), block.timestamp + 20 minutes);

        uint256 bal = usdc.balanceOf(address(this));
        if (bal < assets) revert RepayShort();

        usdc.safeApprove(address(morpho), assets);
        // Morpho pulls `assets` after callback returns
    }

    /// @notice Dust rescue. USDC can only go to Landing (cold law).
    function rescue(address token, address to, uint256 amt) external onlyOwner {
        if (token == address(usdc)) {
            IERC20(token).safeTransfer(landing, amt);
            return;
        }
        if (to == address(0)) to = king;
        IERC20(token).safeTransfer(to, amt);
    }

    function _requireCold(uint256 before, uint256 amt) internal view {
        if (usdc.balanceOf(landing) < before + amt) revert LandingMiss();
    }
}
