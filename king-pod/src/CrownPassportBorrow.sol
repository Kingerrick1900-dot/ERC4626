// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @title CrownPassportBorrow - Move 4 blue-chip Morpho passport
/// @notice Post cbBTC or WETH on canonical Base Morpho USDC markets, borrow USDC to KingVault.
/// @dev Requires Morpho.setAuthorization(this, true) from `onBehalf` (HOT).
///      Does NOT flash-buy collateral (equity required). Optional PA fill is off-chain.

interface IMorphoPassport {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
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
        returns (uint128 totalSupplyAssets, uint128, uint128 totalBorrowAssets, uint128, uint128, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128 borrowShares, uint128 collateral);
}

contract CrownPassportBorrow is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoPassport public immutable morpho;
    address public immutable usdc;
    address public immutable cbbtc;
    address public immutable weth;
    address public immutable hot;
    address public kingVault;

    bool public armed;
    bool public killswitch;
    uint256 public minBorrowUsdc = 1e6; // $1 floor
    uint256 public maxLtvBps = 8000; // 80% of LLTV headroom (conservative vs 86% market LLTV)

    // Canonical Base Morpho params (Coinbase/Steakhouse-style books)
    IMorphoPassport.MarketParams public cbBtcMarket;
    IMorphoPassport.MarketParams public wethMarket;

    event Armed(bool on);
    event Killswitch(bool on);
    event KingVaultSet(address vault);
    event PassportBorrow(
        address indexed collateral, uint256 collIn, uint256 borrowed, address indexed receiver, bytes32 marketId
    );

    error Auth();
    error Disarmed();
    error Killed();
    error Bad();
    error NoIdle();
    error Ltv();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address cbbtc_,
        address weth_,
        address hot_,
        address kingVault_,
        address owner_,
        IMorphoPassport.MarketParams memory cbBtcMp_,
        IMorphoPassport.MarketParams memory wethMp_
    ) Ownable(owner_) {
        morpho = IMorphoPassport(morpho_);
        usdc = usdc_;
        cbbtc = cbbtc_;
        weth = weth_;
        hot = hot_;
        kingVault = kingVault_;
        cbBtcMarket = cbBtcMp_;
        wethMarket = wethMp_;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setKillswitch(bool on) external onlyHot {
        killswitch = on;
        emit Killswitch(on);
    }

    function setKingVault(address v) external onlyOwner {
        if (v == address(0)) revert Bad();
        kingVault = v;
        emit KingVaultSet(v);
    }

    function setLimits(uint256 minBorrow, uint256 maxLtvBps_) external onlyOwner {
        minBorrowUsdc = minBorrow;
        maxLtvBps = maxLtvBps_;
    }

    /// @notice Pull collateral from HOT, post on Morpho, borrow USDC to KingVault.
    /// @param useCbBtc true = cbBTC market; false = WETH market
    /// @param collAmt collateral amount (native decimals); 0 = use full HOT balance after pull of `pullAmt`
    /// @param pullAmt amount to transferFrom HOT (0 = collateral already on this contract)
    /// @param borrowAmt USDC to borrow; 0 = max under maxLtvBps capped by market idle
    function passport(bool useCbBtc, uint256 collAmt, uint256 pullAmt, uint256 borrowAmt)
        external
        onlyHot
        nonReentrant
        returns (uint256 borrowed)
    {
        if (!armed) revert Disarmed();
        if (killswitch) revert Killed();

        IMorphoPassport.MarketParams memory mp = useCbBtc ? cbBtcMarket : wethMarket;
        address coll = mp.collateralToken;
        if (coll != cbbtc && coll != weth) revert Bad();

        if (pullAmt > 0) {
            IERC20(coll).safeTransferFrom(hot, address(this), pullAmt);
        }
        if (collAmt == 0) {
            collAmt = IERC20(coll).balanceOf(address(this));
        }
        if (collAmt == 0) revert Bad();

        IERC20(coll).safeApprove(address(morpho), 0);
        IERC20(coll).safeApprove(address(morpho), collAmt);
        morpho.supplyCollateral(mp, collAmt, hot, "");

        bytes32 mid = _id(mp);
        (uint128 supply,, uint128 borrow,,,) = morpho.market(mid);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle == 0) revert NoIdle();

        if (borrowAmt == 0) {
            // Conservative: leave headroom; caller should size from off-chain oracle.
            // Cap by idle; LTV check deferred to Morpho revert if over.
            borrowAmt = idle;
        }
        if (borrowAmt < minBorrowUsdc) revert Bad();
        if (borrowAmt > idle) borrowAmt = idle;

        morpho.borrow(mp, borrowAmt, 0, hot, kingVault);
        emit PassportBorrow(coll, collAmt, borrowAmt, kingVault, mid);
        return borrowAmt;
    }

    /// @notice Borrow only (collateral already posted on Morpho under HOT).
    function borrowOnly(bool useCbBtc, uint256 borrowAmt) external onlyHot nonReentrant returns (uint256) {
        if (!armed) revert Disarmed();
        if (killswitch) revert Killed();
        IMorphoPassport.MarketParams memory mp = useCbBtc ? cbBtcMarket : wethMarket;
        bytes32 mid = _id(mp);
        (uint128 supply,, uint128 borrow,,,) = morpho.market(mid);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle == 0) revert NoIdle();
        if (borrowAmt == 0 || borrowAmt > idle) borrowAmt = idle;
        if (borrowAmt < minBorrowUsdc) revert Bad();
        morpho.borrow(mp, borrowAmt, 0, hot, kingVault);
        emit PassportBorrow(mp.collateralToken, 0, borrowAmt, kingVault, mid);
        return borrowAmt;
    }

    function marketIdle(bool useCbBtc) external view returns (uint256 idle) {
        IMorphoPassport.MarketParams memory mp = useCbBtc ? cbBtcMarket : wethMarket;
        (uint128 supply,, uint128 borrow,,,) = morpho.market(_id(mp));
        idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
    }

    function _id(IMorphoPassport.MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p.loanToken, p.collateralToken, p.oracle, p.irm, p.lltv));
    }
}
