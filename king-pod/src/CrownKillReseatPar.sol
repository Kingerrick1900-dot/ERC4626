// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoKill {
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
}

interface IOracleKill {
    function price() external view returns (uint256);
    function setPrice(uint256 newPrice) external;
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @notice Kill the $3M SOV loan · reseat RSS on PAR · no re-borrow.
/// @dev Circular book: Kingdom fire LP == 100% SOV supply, matched to Elephant debt.
///      Full-collateral seize at dust oracle → tiny repay + Morpho bad-debt writes off the rest
///      against our own LP (no external supplier). RSS never sold. No PAR draw.
contract CrownKillReseatPar is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    bytes32 public constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;
    address public constant ELEPHANT = 0x03bdf75d11237C0560F48527F360640d9c7ddCAa;

    /// @dev Dust Morpho price — full seize repays pennies; remainder is bad-debt vs Kingdom LP.
    uint256 public constant DUST_LIQ_PRICE = 1e20; // ≪ band; forces bad-debt unwind

    IMorphoKill public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IOracleKill public immutable oracle;

    bool private _locking;

    event KilledAndReseated(
        uint256 seizedRss, uint256 repaidAssets, uint256 badDebtHint, uint256 priceRestored, uint256 parColl
    );

    error OnlyMorpho();
    error NoPos();
    error BadOracle();
    error FlashFail();
    error ElephantDebtRemains();
    error ParMiss();

    constructor(address morpho_, address usdc_, address rss_, address oracle_, address owner_) Ownable(owner_) {
        morpho = IMorphoKill(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        oracle = IOracleKill(oracle_);
        if (oracle.owner() != owner_) revert BadOracle();
    }

    /// @notice Kill Elephant SOV debt · reseat all RSS on PAR as collateral only.
    function killAndReseat() external onlyOwner nonReentrant {
        (, uint128 borShares, uint128 coll) = morpho.position(SOV, ELEPHANT);
        if (borShares == 0 || coll == 0) revert NoPos();

        IMorphoKill.MarketParams memory sovMp = _params(SOV);
        morpho.accrueInterest(sovMp);

        // Flash only needs the tiny liquidate repay (plus buffer), not $3M.
        // At DUST_LIQ_PRICE, repaidAssets from full seize is ≪ $10k; pad hard for safety.
        uint256 flashAmt = 50_000e6;

        uint256 priceBefore = oracle.price();
        _locking = true;
        morpho.flashLoan(address(usdc), flashAmt, abi.encode(priceBefore, uint256(coll)));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();

        (uint256 priceBefore, uint256 collHint) = abi.decode(data, (uint256, uint256));
        IMorphoKill.MarketParams memory sovMp = _params(SOV);
        IMorphoKill.MarketParams memory parMp = _params(PAR);

        usdc.safeApprove(address(morpho), type(uint256).max);
        rss.safeApprove(address(morpho), type(uint256).max);

        morpho.accrueInterest(sovMp);
        (, uint128 liveBor, uint128 liveColl) = morpho.position(SOV, ELEPHANT);
        if (liveBor == 0 || liveColl == 0) revert NoPos();
        uint256 seizeAmt = uint256(liveColl);
        if (seizeAmt == 0) seizeAmt = collHint;

        // 1) Dust oracle → seize ALL Elephant RSS; Morpho bad-debt clears residual vs Kingdom LP.
        oracle.setPrice(DUST_LIQ_PRICE);
        (uint256 seized, uint256 repaidAssets) = morpho.liquidate(sovMp, ELEPHANT, seizeAmt, 0, "");
        if (seized == 0) revert FlashFail();

        (, uint128 borAfter, uint128 collAfter) = morpho.position(SOV, ELEPHANT);
        if (borAfter != 0) revert ElephantDebtRemains();
        // collAfter should be 0 after full seize; allow dust
        collAfter; // silence

        // 2) Restore King price before posting on PAR.
        oracle.setPrice(priceBefore);

        uint256 rssBal = rss.balanceOf(address(this));
        if (rssBal == 0) revert FlashFail();

        // 3) Reseat on PAR — collateral only. No borrow. Ceiling $4.28B waits on idle seed.
        morpho.supplyCollateral(parMp, rssBal, address(this), "");
        (, , uint128 parColl) = morpho.position(PAR, address(this));
        if (parColl == 0) revert ParMiss();

        if (usdc.balanceOf(address(this)) < assets) revert FlashFail();
        usdc.safeApprove(address(morpho), assets);

        oracle.transferOwnership(owner);

        uint256 badDebtHint = repaidAssets < 3_000_000e6 ? (3_000_000e6 - repaidAssets) : 0;
        emit KilledAndReseated(seized, repaidAssets, badDebtHint, priceBefore, uint256(parColl));
    }

    function _params(bytes32 id) internal view returns (IMorphoKill.MarketParams memory mp) {
        (address a, address b, address c, address d, uint256 e) = morpho.idToMarketParams(id);
        mp = IMorphoKill.MarketParams(a, b, c, d, e);
    }
}
