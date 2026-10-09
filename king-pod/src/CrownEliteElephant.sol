// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoEl {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function accrueInterest(MarketParams memory marketParams) external;

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes memory data
    ) external returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

interface IOracleEl {
    function price() external view returns (uint256);
    function setPrice(uint256 newPrice) external;
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @notice Elite Elephant — atomic self-del migrate: legacy SOV book → parallel 38.5% rail.
/// @dev Morpho flash (0%) · temp oracle self-del · reseat RSS on PAR · borrow · restore oracle · repay flash.
///      RSS never sold — seized to this Kingdom contract and re-posted as collateral.
contract CrownEliteElephant is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    bytes32 public constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;
    address public constant LEGACY_GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;

    /// @dev Morpho price low enough that 222k RSS @ 77% LLTV cannot cover ~$3M debt.
    uint256 public constant LIQ_PRICE = 1e25; // ~$10 / RSS on Morpho scale

    IMorphoEl public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IOracleEl public immutable oracle;

    bool private _locking;

    event ElephantWalked(
        uint256 debtRepaidShares, uint256 rssSeized, uint256 borrowedPar, uint256 priceRestored
    );

    error OnlyMorpho();
    error NoPos();
    error Short();
    error BadOracle();
    error FlashFail();

    constructor(address morpho_, address usdc_, address rss_, address oracle_, address owner_) Ownable(owner_) {
        morpho = IMorphoEl(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        oracle = IOracleEl(oracle_);
        if (oracle.owner() != owner_) revert BadOracle();
    }

    /// @notice Fire the atomic migration. HOT/owner only. ZK doctrine: RSS stays collateral.
    function fire() external onlyOwner nonReentrant {
        (, uint128 borShares, uint128 coll) = morpho.position(SOV, LEGACY_GATE);
        if (borShares == 0 || coll == 0) revert NoPos();

        IMorphoEl.MarketParams memory sovMp = _params(SOV);
        morpho.accrueInterest(sovMp);
        (,, uint128 tba, uint128 tbs,,) = morpho.market(SOV);
        uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
        flashAmt += 5_000e6; // buffer for accrue during callback

        uint256 priceBefore = oracle.price();
        _locking = true;
        morpho.flashLoan(
            address(usdc), flashAmt, abi.encode(priceBefore, uint256(borShares), uint256(coll))
        );
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();

        (uint256 priceBefore, uint256 borShares, uint256 coll) =
            abi.decode(data, (uint256, uint256, uint256));

        IMorphoEl.MarketParams memory sovMp = _params(SOV);
        IMorphoEl.MarketParams memory parMp = _params(PAR);

        usdc.safeApprove(address(morpho), type(uint256).max);
        rss.safeApprove(address(morpho), type(uint256).max);

        // 1) Self-del: drop oracle so Gate is liquidatable, seize RSS by repaying debt.
        oracle.setPrice(LIQ_PRICE);
        (uint256 seized, uint256 repaidShares) =
            morpho.liquidate(sovMp, LEGACY_GATE, 0, borShares, "");
        if (seized == 0) {
            // fallback: seize by collateral amount
            (seized, repaidShares) = morpho.liquidate(sovMp, LEGACY_GATE, coll, 0, "");
        }

        uint256 rssBal = rss.balanceOf(address(this));
        if (rssBal == 0) revert FlashFail();

        // 2) Restore oracle before opening the parallel book at true King price.
        oracle.setPrice(priceBefore);

        // 3) Post RSS on parallel rail (this contract = Kingdom position vault).
        morpho.supplyCollateral(parMp, rssBal, address(this), "");

        // 4) Borrow USDC to repay flash (conservative: flash size).
        uint256 need = assets;
        (uint256 borrowed,) = morpho.borrow(parMp, need, 0, address(this), address(this));

        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.safeApprove(address(morpho), assets);

        // Return oracle to King HOT before flash ends.
        oracle.transferOwnership(owner);

        emit ElephantWalked(repaidShares, seized, borrowed, priceBefore);
    }

    function _params(bytes32 id) internal view returns (IMorphoEl.MarketParams memory mp) {
        (address a, address b, address c, address d, uint256 e) = morpho.idToMarketParams(id);
        mp = IMorphoEl.MarketParams(a, b, c, d, e);
    }
}
