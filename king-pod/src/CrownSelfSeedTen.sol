// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice $10-oracle self-seed: flash USDC → supply market → borrow vs ELE → repay flash.
/// @dev Morpho Blue APIs (draft corrected):
///      - onMorphoFlashLoan(assets, data) — no fee arg; fee = 0; repay via approve+pull
///      - supply(..., onBehalf, bytes data) — not receiver
///      - supplyCollateral(..., onBehalf, bytes data) — not receiver
///      - ELE is 8 decimals
///      Matched self-seed leaves king with ELE coll + USDC supply + USDC debt; wallet Δ USDC ≈ 0.
interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

contract CrownSelfSeedTen {
    address public immutable king;
    address public immutable oracle;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;

    bool private locking;
    uint256 private flashAmt;

    error NotKing();
    error BadCb();
    error NoEle();
    error NoIdle();
    error NotAuth();

    event SelfSeeded(bytes32 marketId, uint256 eleColl, uint256 usdcSeed, address oracle);

    constructor(address king_, address oracle_) {
        king = king_;
        oracle = oracle_;
    }

    function _mp() internal view returns (IMorphoT.MarketParams memory) {
        return IMorphoT.MarketParams(USDC, ELE, oracle, IRM, LLTV_915);
    }

    function marketId() public view returns (bytes32) {
        return keccak256(abi.encode(_mp()));
    }

    /// @param eleAmount ELE (8dp) to pull from king as collateral; 0 = full wallet
    /// @param usdcSeed flash/supply/borrow size (6dp)
    function selfSeed(uint256 eleAmount, uint256 usdcSeed) external {
        if (msg.sender != king) revert NotKing();
        if (usdcSeed == 0) revert NoIdle();

        if (eleAmount == 0) eleAmount = IERC20T(ELE).balanceOf(king);
        if (eleAmount == 0) revert NoEle();
        // borrow(onBehalf=king) requires Morpho setAuthorization(helper, true)
        if (!IMorphoT(MORPHO).isAuthorized(king, address(this))) revert NotAuth();

        // Pull + post ELE collateral on behalf of king (king owns the Morpho position)
        IERC20T(ELE).transferFrom(king, address(this), eleAmount);
        IERC20T(ELE).approve(MORPHO, eleAmount);
        IMorphoT(MORPHO).supplyCollateral(_mp(), eleAmount, king, "");

        flashAmt = usdcSeed;
        locking = true;
        IMorphoT(MORPHO).flashLoan(USDC, usdcSeed, "");
        locking = false;

        emit SelfSeeded(marketId(), eleAmount, usdcSeed, oracle);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO || !locking) revert BadCb();
        if (assets != flashAmt) revert BadCb();

        IMorphoT.MarketParams memory mp = _mp();

        // 1) Seed market — supply flash USDC on behalf of king
        IERC20T(USDC).approve(MORPHO, assets);
        IMorphoT(MORPHO).supply(mp, assets, 0, king, "");

        // 2) Borrow same size against ELE @ $10 / 91.5% → this contract (flash repay)
        IMorphoT(MORPHO).accrueInterest(mp);
        (uint128 sa,, uint128 ba,,,) = IMorphoT(MORPHO).market(marketId());
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        if (idle < assets) revert NoIdle();
        IMorphoT(MORPHO).borrow(mp, assets, 0, king, address(this));

        // 3) Morpho pulls flash principal after callback
        IERC20T(USDC).approve(MORPHO, assets);
    }
}
