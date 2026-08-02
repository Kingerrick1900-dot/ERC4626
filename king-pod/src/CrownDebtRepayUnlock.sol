// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Flash-repay king Morpho debt → withdraw/redeem yELE-K → repay flash.
/// @dev Morpho flash fee = 0; repayment via approve + transferFrom after callback.
///      Withdraw ONLY what repay frees (maxWithdraw after repay). Full-share redeem
///      can hit NotEnoughLiquidity from queue rounding / WETH stub position.
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
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IVaultD {
    function balanceOf(address) external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function previewRedeem(uint256) external view returns (uint256);
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

    error NotKing();
    error BadCb();
    error Short();
    error NoLiquidity();

    constructor(address king_, address vault_) {
        king = king_;
        vault = vault_;
    }

    /// @param flashAssets USDC to flash and repay against king debt (sizes the idle freed)
    /// @param owner_ yELE-K share owner (must approve this contract)
    /// @param to_ dust receiver after Morpho pulls flash repay
    function unlock(uint256 flashAssets, address owner_, address to_) external {
        if (msg.sender != king) revert NotKing();
        shareOwner = owner_;
        receiver = to_;
        locking = true;
        IMorphoD(MORPHO).flashLoan(USDC, flashAssets, "");
        locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO || !locking) revert BadCb();

        IMorphoD.MarketParams memory mp =
            IMorphoD.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
        IMorphoD(MORPHO).accrueInterest(mp);

        // 1) Repay king debt → frees Morpho idle on ELE/USDC
        IERC20D(USDC).approve(MORPHO, assets);
        IMorphoD(MORPHO).repay(mp, assets, 0, king, "");

        // 2) Pull exactly `assets` — Morpho pulls the same amount after callback.
        //    Full-share redeem overshoots idle (NotEnoughLiquidity); size flash to freeable.
        uint256 liquid = IVaultD(vault).maxWithdraw(shareOwner);
        if (liquid < assets) revert NoLiquidity();

        uint256 out = IVaultD(vault).withdraw(assets, address(this), shareOwner);
        if (out < assets) revert Short();

        // 3) Morpho pulls flash principal via transferFrom after callback
        IERC20D(USDC).approve(MORPHO, assets);

        uint256 bal = IERC20D(USDC).balanceOf(address(this));
        if (bal > assets) {
            IERC20D(USDC).transfer(receiver, bal - assets);
        }
    }
}
