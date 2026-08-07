// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Self-del: flash → repay Morpho debt → withdraw supply → free RSS to king → freeze.
/// @dev Targets main RSS book (MID 0x41c08085…). No re-lock.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorpho {
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
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

contract CrownSelfDelFree {
    IMorpho public immutable morpho;
    IERC20 public immutable usdc;
    address public immutable king;
    bytes32 public immutable marketId;
    address public immutable loanToken;
    address public immutable collToken;
    address public immutable oracle;
    address public immutable irm;
    uint256 public immutable lltv;

    uint256 public lastDebtRepaid;
    uint256 public lastRssFreed;
    bool public lastClosed;

    error NotKing();
    error NotMorpho();
    error NoPos();
    error Short();

    event Freed(uint256 debtRepaid, uint256 supplyPulled, uint256 rssFreed);

    constructor(
        address morpho_,
        address usdc_,
        address king_,
        bytes32 marketId_,
        address loanToken_,
        address collToken_,
        address oracle_,
        address irm_,
        uint256 lltv_
    ) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        king = king_;
        marketId = marketId_;
        loanToken = loanToken_;
        collToken = collToken_;
        oracle = oracle_;
        irm = irm_;
        lltv = lltv_;
    }

    function _mp() internal view returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams(loanToken, collToken, oracle, irm, lltv);
    }

    /// @notice Close self-loop as far as Morpho cash allows; free excess RSS to king.
    function freeRss() external {
        if (msg.sender != king) revert NotKing();
        IMorpho.MarketParams memory p = _mp();
        morpho.accrueInterest(p);

        (uint256 supShares, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        if (borShares == 0 && coll == 0) revert NoPos();

        uint256 flashAmt;
        if (borShares > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            uint256 debt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
            uint256 cash = usdc.balanceOf(address(morpho));
            // leave $1M headroom in Morpho for other markets
            uint256 maxFlash = cash > 1_000_000e6 ? cash - 1_000_000e6 : 0;
            flashAmt = debt < maxFlash ? debt : maxFlash;
            // tiny buffer only if full close fits
            if (flashAmt == debt && maxFlash > debt + 100e6) flashAmt = debt + 100e6;
        }

        if (flashAmt > 0) {
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(supShares, uint256(borShares), uint256(coll), flashAmt));
        } else if (coll > 0) {
            morpho.withdrawCollateral(p, coll, king, king);
            lastRssFreed = coll;
            lastClosed = true;
            emit Freed(0, 0, coll);
        }
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert NotMorpho();
        (, , , uint256 flashAmt) = abi.decode(data, (uint256, uint256, uint256, uint256));
        require(assets == flashAmt, "FLASH");

        IMorpho.MarketParams memory p = _mp();
        usdc.approve(address(morpho), type(uint256).max);

        // 1) Repay debt (assets mode — partial OK if Morpho cash < full debt)
        morpho.accrueInterest(p);
        (, uint128 borNow,) = morpho.position(marketId, king);
        if (borNow > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            uint256 debtNow = (uint256(tba) * uint256(borNow) + uint256(tbs) - 1) / uint256(tbs);
            uint256 repayAmt = flashAmt < debtNow ? flashAmt : debtNow;
            // leave dust if not full close to avoid share rounding blowups
            if (repayAmt == debtNow && repayAmt > 1e6) {
                morpho.repay(p, 0, borNow, king, ""); // full shares
                lastDebtRepaid = debtNow;
            } else {
                if (repayAmt > 1e6) repayAmt -= 1e6; // keep $1 dust if partial
                morpho.repay(p, repayAmt, 0, king, "");
                lastDebtRepaid = repayAmt;
            }
        }

        // 2) Pull USDC supply to cover flash
        (uint256 supNow,,) = morpho.position(marketId, king);
        uint256 pulled;
        if (supNow > 0) {
            (pulled,) = morpho.withdraw(p, 0, supNow, king, address(this));
        }

        // 3) Free RSS collateral to king (keep buffer vs any leftover debt)
        morpho.accrueInterest(p);
        (, uint128 borLeft, uint128 collLeft) = morpho.position(marketId, king);
        uint256 keep;
        if (borLeft > 0) {
            (,, uint128 tba2, uint128 tbs2,,) = morpho.market(marketId);
            uint256 debtLeft = (uint256(tba2) * uint256(borLeft) + uint256(tbs2) - 1) / uint256(tbs2);
            keep = (debtLeft * 1e18) / lltv;
            keep += keep / 10; // +10% cushion
            keep += 400 ether; // RSS buffer
        }
        uint256 freed;
        if (collLeft > keep) {
            freed = uint256(collLeft) - keep;
            morpho.withdrawCollateral(p, freed, king, king);
        }
        lastRssFreed = freed;

        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) revert Short();
        usdc.approve(address(morpho), assets);

        uint256 dust = have - assets;
        if (dust > 0) usdc.transfer(king, dust);

        lastClosed = true;
        emit Freed(lastDebtRepaid, pulled, freed);
    }
}
