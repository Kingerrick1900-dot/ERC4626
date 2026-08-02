// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice King's TEN spoil claim — flash-repay debt → withdraw matched USDC supply → repay flash.
/// @dev Morpho flash fee = 0. Wallet Δ USDC ≈ 0 on a matched book (spoil cycles under King's hand).
///      Net seed on hot requires desk wire ≥ debt, then FireTenSpoilsClaim (no flash).
///      Optional PULL_ELE withdraws free / all collateral after debt clear.
interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

/// @title CrownTenSpoilsWar
/// @notice Muster the $700k TEN spoil. Flash path proves dominion; wire path keeps the seed.
contract CrownTenSpoilsWar {
    address public immutable king;
    address public immutable oracle;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;

    bool private locking;
    bool private pullEle;
    uint256 private flashAmt;

    error NotKing();
    error BadCb();
    error NotAuth();
    error NoDebt();
    error Short();

    event SpoilsMustered(bytes32 marketId, uint256 debtRepaid, uint256 supplyPulled, uint256 elePulled, uint256 hotUsdc);

    constructor(address king_, address oracle_) {
        king = king_;
        oracle = oracle_;
    }

    function _mp() internal view returns (IMorphoS.MarketParams memory) {
        return IMorphoS.MarketParams(USDC, ELE, oracle, IRM, LLTV_915);
    }

    function marketId() public view returns (bytes32) {
        return keccak256(abi.encode(_mp()));
    }

    /// @notice Flash-muster: repay TEN debt, pull king's supply to this contract, repay flash, skim dust to king.
    /// @param pullEle_ if true, withdraw all ELE coll to king after debt cleared
    function musterFlash(bool pullEle_) external {
        if (msg.sender != king) revert NotKing();
        if (!IMorphoS(MORPHO).isAuthorized(king, address(this))) revert NotAuth();

        IMorphoS.MarketParams memory mp = _mp();
        IMorphoS(MORPHO).accrueInterest(mp);
        bytes32 id = marketId();
        (, uint128 borShares,) = IMorphoS(MORPHO).position(id, king);
        if (borShares == 0) revert NoDebt();
        (,, uint128 ba, uint128 bs,,) = IMorphoS(MORPHO).market(id);
        uint256 debt = (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);

        pullEle = pullEle_;
        flashAmt = debt;
        locking = true;
        IMorphoS(MORPHO).flashLoan(USDC, debt, "");
        locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO || !locking) revert BadCb();
        if (assets != flashAmt) revert BadCb();

        IMorphoS.MarketParams memory mp = _mp();
        bytes32 id = marketId();

        (, uint128 borShares,) = IMorphoS(MORPHO).position(id, king);
        IERC20S(USDC).approve(MORPHO, assets);
        IMorphoS(MORPHO).repay(mp, 0, borShares, king, "");

        (uint256 supShares,, uint128 coll) = IMorphoS(MORPHO).position(id, king);
        uint256 pulled;
        if (supShares > 0) {
            (pulled,) = IMorphoS(MORPHO).withdraw(mp, 0, supShares, king, address(this));
        }

        uint256 elePulled;
        if (pullEle && coll > 0) {
            IMorphoS(MORPHO).withdrawCollateral(mp, uint256(coll), king, king);
            elePulled = uint256(coll);
        }

        // Morpho pulls flash principal after callback
        IERC20S(USDC).approve(MORPHO, assets);
        uint256 bal = IERC20S(USDC).balanceOf(address(this));
        if (bal < assets) revert Short();
        if (bal > assets) {
            IERC20S(USDC).transfer(king, bal - assets);
        }

        emit SpoilsMustered(id, assets, pulled, elePulled, IERC20S(USDC).balanceOf(king));
    }
}
