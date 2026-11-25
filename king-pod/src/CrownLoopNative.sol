// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoLoop {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @title CrownLoopNative
/// @notice Atomic Morpho flash self-seed on eUSD/USDC synth market — one block, one tap.
/// @dev Flash USDC → supply market depth → post eUSD coll onBehalf king → borrow → repay flash.
///      End: king Morpho supply+borrow+collateral scaled. Wallet USDC unchanged (flash closes).
///      Matches Ethena/Falcon atomic seed; no outside lender. Morpho flash fee = 0.
contract CrownLoopNative is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoLoop public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoLoop.MarketParams public mp;

    bool private _locking;
    uint256 public totalFlashed;
    uint256 public totalCollateralPosted;
    uint256 public fires;

    event Looped(uint256 flashUsdc, uint256 eusdColl, uint256 borrowUsdc, uint256 fireId);

    error OnlyMorpho();
    error BadAmt();
    error Idle();
    error Auth();

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
        morpho = IMorphoLoop(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        king = king_;
        mp = IMorphoLoop.MarketParams({
            loanToken: usdc_,
            collateralToken: eusd_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        marketId = keccak256(abi.encode(mp));
    }

    /// @notice Fire atomic loop. `flashUsdc` = Morpho flash size (6dp). `eusdColl` = collateral to post (18dp).
    /// @dev Requires: king Morpho.setAuthorization(this,true); eUSD allowance from king; eUSD balance ≥ eusdColl.
    ///      LTV check: flashUsdc * 1e12 <= eusdColl * lltv / 1e18  (oracle $1).
    function fire(uint256 flashUsdc, uint256 eusdColl) external onlyKing nonReentrant {
        if (flashUsdc < 1e6) revert BadAmt(); // min $1
        if (eusdColl == 0) revert BadAmt();
        // flashUsdc (6dp) value vs eusdColl (18dp) @ $1 and lltv
        if (flashUsdc * 1e12 * 1e18 > eusdColl * mp.lltv) revert BadAmt();

        eusd.safeTransferFrom(king, address(this), eusdColl);
        eusd.approve(address(morpho), eusdColl);
        morpho.supplyCollateral(mp, eusdColl, king, "");

        _locking = true;
        morpho.flashLoan(address(usdc), flashUsdc, abi.encode(flashUsdc, eusdColl));
        _locking = false;

        totalFlashed += flashUsdc;
        totalCollateralPosted += eusdColl;
        fires += 1;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 flashUsdc, uint256 eusdColl) = abi.decode(data, (uint256, uint256));
        if (assets != flashUsdc) revert BadAmt();

        // 1) Seed market depth with flashed USDC (onBehalf king)
        usdc.approve(address(morpho), assets);
        morpho.supply(mp, assets, 0, king, "");

        // 2) Borrow same USDC against king's eUSD collateral to close flash
        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert Idle();

        morpho.borrow(mp, assets, 0, king, address(this));

        // 3) Repay Morpho flash (fee = 0)
        usdc.approve(address(morpho), assets);
        emit Looped(assets, eusdColl, assets, fires + 1);
    }
}
