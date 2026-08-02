// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice $10-oracle kXAU/USDC self-seed: flash USDC → supply → borrow vs gold → repay.
/// @dev Same physics as CrownSelfSeedTen. Wallet Δ USDC ≈ 0; king holds coll+supply+debt.
interface IERC20G {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoG {
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

contract CrownSelfSeedGold {
    address public immutable king;
    address public immutable gold;
    address public immutable oracle;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;

    bool private locking;
    uint256 private flashAmt;

    error NotKing();
    error BadCb();
    error NoGold();
    error NoIdle();
    error NotAuth();

    event SelfSeeded(bytes32 marketId, uint256 goldColl, uint256 usdcSeed, address oracle);

    constructor(address king_, address gold_, address oracle_) {
        king = king_;
        gold = gold_;
        oracle = oracle_;
    }

    function _mp() internal view returns (IMorphoG.MarketParams memory) {
        return IMorphoG.MarketParams(USDC, gold, oracle, IRM, LLTV_915);
    }

    function marketId() public view returns (bytes32) {
        return keccak256(abi.encode(_mp()));
    }

    /// @param goldAmount kXAU (8dp) from king; 0 = full wallet
    /// @param usdcSeed flash/supply/borrow size (6dp)
    function selfSeed(uint256 goldAmount, uint256 usdcSeed) external {
        if (msg.sender != king) revert NotKing();
        if (usdcSeed == 0) revert NoIdle();

        if (goldAmount == 0) goldAmount = IERC20G(gold).balanceOf(king);
        if (goldAmount == 0) revert NoGold();
        if (!IMorphoG(MORPHO).isAuthorized(king, address(this))) revert NotAuth();

        IERC20G(gold).transferFrom(king, address(this), goldAmount);
        IERC20G(gold).approve(MORPHO, goldAmount);
        IMorphoG(MORPHO).supplyCollateral(_mp(), goldAmount, king, "");

        flashAmt = usdcSeed;
        locking = true;
        IMorphoG(MORPHO).flashLoan(USDC, usdcSeed, "");
        locking = false;

        emit SelfSeeded(marketId(), goldAmount, usdcSeed, oracle);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO || !locking) revert BadCb();
        if (assets != flashAmt) revert BadCb();

        IMorphoG.MarketParams memory mp = _mp();

        IERC20G(USDC).approve(MORPHO, assets);
        IMorphoG(MORPHO).supply(mp, assets, 0, king, "");

        IMorphoG(MORPHO).accrueInterest(mp);
        (uint128 sa,, uint128 ba,,,) = IMorphoG(MORPHO).market(marketId());
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        if (idle < assets) revert NoIdle();
        IMorphoG(MORPHO).borrow(mp, assets, 0, king, address(this));

        IERC20G(USDC).approve(MORPHO, assets);
    }
}
