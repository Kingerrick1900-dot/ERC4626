// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Elite force: do not wait on idle — flash-repay debt → pull shares/supply → close flash.
/// @dev Matched books ⇒ wallet Δ USDC ≈ 0 (deleverage). Unmatched idle or surplus skims to king.
///      Modes: vault ERC4626 redeem path, or direct Morpho supply-share withdraw.
interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoU {
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
    function accrueInterest(MarketParams memory) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IVaultU {
    function maxWithdraw(address) external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

contract CrownForceShareUsdc {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    address public immutable king;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    bool private locking;
    uint8 private mode; // 1=vault, 2=morphoSupply
    address private vault;
    address private receiver;
    MarketParams private mp;
    uint256 private flashAmt;

    error NotKing();
    error BadCb();
    error NotAuth();
    error Short();
    error NoLiq();

    event Forced(uint8 mode, uint256 flashAssets, uint256 pulled, uint256 skimToKing);

    constructor(address king_) {
        king = king_;
    }

    function _toMorpho(MarketParams memory p) internal pure returns (IMorphoU.MarketParams memory) {
        return IMorphoU.MarketParams(p.loanToken, p.collateralToken, p.oracle, p.irm, p.lltv);
    }

    /// @notice Force vault shares → USDC: flash repay king debt on `mp_` → vault.withdraw → repay flash.
    function forceVault(address vault_, MarketParams calldata mp_, uint256 flashAssets, address to_) external {
        if (msg.sender != king) revert NotKing();
        require(flashAssets > 0 && vault_ != address(0), "ARGS");
        vault = vault_;
        mp = mp_;
        receiver = to_ == address(0) ? king : to_;
        mode = 1;
        flashAmt = flashAssets;
        locking = true;
        IMorphoU(MORPHO).flashLoan(USDC, flashAssets, "");
        locking = false;
    }

    /// @notice Force Morpho supply shares → USDC on market `mp_`.
    function forceMorphoSupply(MarketParams calldata mp_, uint256 flashAssets, address to_) external {
        if (msg.sender != king) revert NotKing();
        if (!IMorphoU(MORPHO).isAuthorized(king, address(this))) revert NotAuth();
        require(flashAssets > 0, "ARGS");
        mp = mp_;
        receiver = to_ == address(0) ? king : to_;
        mode = 2;
        flashAmt = flashAssets;
        locking = true;
        IMorphoU(MORPHO).flashLoan(USDC, flashAssets, "");
        locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO || !locking) revert BadCb();
        if (assets != flashAmt) revert BadCb();

        IMorphoU.MarketParams memory marketParams = _toMorpho(mp);
        IMorphoU(MORPHO).accrueInterest(marketParams);
        bytes32 id = keccak256(abi.encode(marketParams));

        (, uint128 borShares,) = IMorphoU(MORPHO).position(id, king);
        IERC20U(USDC).approve(MORPHO, assets);
        if (borShares > 0) {
            (,, uint128 ba, uint128 bs,,) = IMorphoU(MORPHO).market(id);
            uint256 debt =
                bs == 0 ? 0 : (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
            uint256 repayAmt = assets < debt ? assets : debt;
            if (repayAmt > 0) {
                if (repayAmt == debt) {
                    IMorphoU(MORPHO).repay(marketParams, 0, borShares, king, "");
                } else {
                    IMorphoU(MORPHO).repay(marketParams, repayAmt, 0, king, "");
                }
            }
        }

        uint256 pulled;
        if (mode == 1) {
            uint256 liquid = IVaultU(vault).maxWithdraw(king);
            if (liquid < assets) revert NoLiq();
            pulled = IVaultU(vault).withdraw(assets, address(this), king);
        } else if (mode == 2) {
            (uint256 supShares,,) = IMorphoU(MORPHO).position(id, king);
            if (supShares == 0) revert NoLiq();
            (uint128 sa, uint128 ss,,,,) = IMorphoU(MORPHO).market(id);
            uint256 supplyAssets = ss == 0 ? 0 : (supShares * uint256(sa)) / uint256(ss);
            uint256 take = assets < supplyAssets ? assets : supplyAssets;
            if (take == supplyAssets) {
                (pulled,) = IMorphoU(MORPHO).withdraw(marketParams, 0, supShares, king, address(this));
            } else {
                (pulled,) = IMorphoU(MORPHO).withdraw(marketParams, take, 0, king, address(this));
            }
        } else {
            revert BadCb();
        }

        if (pulled < assets) revert Short();
        IERC20U(USDC).approve(MORPHO, assets);

        uint256 bal = IERC20U(USDC).balanceOf(address(this));
        uint256 skim;
        if (bal > assets) {
            skim = bal - assets;
            IERC20U(USDC).transfer(receiver, skim);
        }
        emit Forced(mode, assets, pulled, skim);
    }
}
