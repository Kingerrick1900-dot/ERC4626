// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Flash-repay king Morpho debt → redeem yELE-K → repay flash.
/// @dev Morpho Blue flash: callback is onMorphoFlashLoan(assets, data); fee = 0;
///      Morpho pulls repayment via transferFrom after callback (approve, do not transfer).
///      Matched pot: redeem ≈ flash body → net ops USDC ≈ 0; shares cleared.
interface IERC20D {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoD {
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
    function accrueInterest(MarketParams memory) external;
}

interface IVaultD {
    function balanceOf(address) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

contract CrownDebtRepayUnlock {
    address public immutable king;
    address public immutable vault;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_77 = 770000000000000000;

    bool private locking;
    address private shareOwner;
    address private receiver;
    uint256 private shareAmt;

    error NotKing();
    error BadCb();
    error Short();

    constructor(address king_, address vault_) {
        king = king_;
        vault = vault_;
    }

    /// @param flashAssets USDC to flash (= share claim / debt slice to free)
    /// @param shares yELE-K shares to redeem (owner must have approved this contract)
    /// @param owner_ share owner (hot)
    /// @param to_ receives any dust leftover after Morpho pulls flash repay
    function unlock(uint256 flashAssets, uint256 shares, address owner_, address to_) external {
        if (msg.sender != king) revert NotKing();
        shareOwner = owner_;
        receiver = to_;
        shareAmt = shares;
        locking = true;
        IMorphoD(MORPHO).flashLoan(USDC, flashAssets, "");
        locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO || !locking) revert BadCb();

        IMorphoD.MarketParams memory mp =
            IMorphoD.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
        IMorphoD(MORPHO).accrueInterest(mp);

        // 1) Repay king debt → frees vault Morpho supply as idle
        IERC20D(USDC).approve(MORPHO, assets);
        IMorphoD(MORPHO).repay(mp, assets, 0, king, "");

        // 2) Redeem shares → USDC here
        uint256 out = IVaultD(vault).redeem(shareAmt, address(this), shareOwner);
        if (out + 1e6 < assets) revert Short();

        // 3) Approve Morpho to pull flash principal after callback
        IERC20D(USDC).approve(MORPHO, assets);

        // 4) Dust (if any) → receiver. Matched book → typically 0.
        uint256 bal = IERC20D(USDC).balanceOf(address(this));
        if (bal > assets) {
            IERC20D(USDC).transfer(receiver, bal - assets);
        }
    }
}
