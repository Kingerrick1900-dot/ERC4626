// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Atomic kingdom unwind: Morpho flash → repay debt → pull supply → pull ELE coll → repay flash.
/// @dev Matched books ⇒ net hot USDC ≈ dust only. King must Morpho-authorize this contract.
interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
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
    function accrueInterest(MarketParams memory) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function isAuthorized(address, address) external view returns (bool);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
}

contract CrownUnwindBook {
    address public immutable king;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    bool private locking;
    IMorphoU.MarketParams private mp;
    uint256 private flashAmt;

    error NotKing();
    error NotAuth();
    error BadCb();
    error Short();

    event Unwound(bytes32 id, uint256 flashAssets, uint256 elePulled);

    constructor(address king_) {
        king = king_;
    }

    /// @notice One-tx close of king's matched Morpho book + pull all ELE collateral to king.
    function unwind(address oracle, uint256 lltv, uint256 flashBuffer) external {
        if (msg.sender != king) revert NotKing();
        if (!IMorphoU(MORPHO).isAuthorized(king, address(this))) revert NotAuth();

        address ele = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
        address irm = 0x46415998764C29aB2a25CbeA6254146D50D22687;
        IMorphoU.MarketParams memory mp_ = IMorphoU.MarketParams(USDC, ele, oracle, irm, lltv);
        mp = mp_;
        IMorphoU(MORPHO).accrueInterest(mp_);
        bytes32 id = keccak256(abi.encode(mp_));
        (uint256 sup, uint128 bor, uint128 coll0) = IMorphoU(MORPHO).position(id, king);

        if (bor > 0 && sup > 0) {
            (uint128 sa, uint128 ss, uint128 ba, uint128 bs,,) = IMorphoU(MORPHO).market(id);
            uint256 debt = (uint256(bor) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
            uint256 supplyAssets = (sup * uint256(sa)) / uint256(ss);
            uint256 flash = debt < supplyAssets ? debt : supplyAssets;
            uint256 buf = flashBuffer == 0 ? 10 : flashBuffer;
            require(flash > buf, "FLASH_DUST");
            flashAmt = flash - buf;
            locking = true;
            IMorphoU(MORPHO).flashLoan(USDC, flashAmt, "");
            locking = false;
        }

        // Dust debt: pay from king USDC (king approved this contract)
        IMorphoU(MORPHO).accrueInterest(mp_);
        (sup, bor,) = IMorphoU(MORPHO).position(id, king);
        if (bor > 0) {
            (,, uint128 ba2, uint128 bs2,,) = IMorphoU(MORPHO).market(id);
            uint256 dust = (uint256(bor) * uint256(ba2) + uint256(bs2) - 1) / uint256(bs2);
            require(IERC20U(USDC).transferFrom(king, address(this), dust), "DUST");
            IERC20U(USDC).approve(MORPHO, dust);
            IMorphoU(MORPHO).repay(mp_, 0, bor, king, "");
        }

        (sup,,) = IMorphoU(MORPHO).position(id, king);
        if (sup > 0) IMorphoU(MORPHO).withdraw(mp_, 0, sup, king, king);

        (,, uint128 coll) = IMorphoU(MORPHO).position(id, king);
        if (coll > 0) IMorphoU(MORPHO).withdrawCollateral(mp_, uint256(coll), king, king);

        uint256 left = IERC20U(USDC).balanceOf(address(this));
        if (left > 0) IERC20U(USDC).transfer(king, left);

        emit Unwound(id, flashAmt, uint256(coll0));
        flashAmt = 0;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO || !locking) revert BadCb();
        if (assets != flashAmt) revert BadCb();

        IMorphoU.MarketParams memory marketParams = mp;
        IMorphoU(MORPHO).accrueInterest(marketParams);
        bytes32 id = keccak256(abi.encode(marketParams));

        (, uint128 borShares,) = IMorphoU(MORPHO).position(id, king);
        IERC20U(USDC).approve(MORPHO, assets);
        if (borShares > 0) {
            (,, uint128 ba, uint128 bs,,) = IMorphoU(MORPHO).market(id);
            uint256 debt = bs == 0 ? 0 : (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
            uint256 repayAmt = assets < debt ? assets : debt;
            if (repayAmt > 0) {
                if (repayAmt == debt) IMorphoU(MORPHO).repay(marketParams, 0, borShares, king, "");
                else IMorphoU(MORPHO).repay(marketParams, repayAmt, 0, king, "");
            }
        }

        (uint256 supShares,,) = IMorphoU(MORPHO).position(id, king);
        if (supShares == 0) revert Short();
        (uint128 sa, uint128 ss,,,,) = IMorphoU(MORPHO).market(id);
        uint256 supplyAssets = ss == 0 ? 0 : (supShares * uint256(sa)) / uint256(ss);
        uint256 take = assets < supplyAssets ? assets : supplyAssets;
        uint256 pulled;
        if (take == supplyAssets) {
            (pulled,) = IMorphoU(MORPHO).withdraw(marketParams, 0, supShares, king, address(this));
        } else {
            (pulled,) = IMorphoU(MORPHO).withdraw(marketParams, take, 0, king, address(this));
        }
        if (pulled < assets) revert Short();
        IERC20U(USDC).approve(MORPHO, assets);
    }
}
