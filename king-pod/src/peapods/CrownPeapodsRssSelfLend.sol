// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownRssPodWrap} from "./CrownRssPodWrap.sol";
import {CrownFusdVault} from "./CrownFusdVault.sol";
import {CrownPeapodsPair} from "./CrownPeapodsPair.sol";

interface IMorphoFlash {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashCb {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IUniV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

/// @notice Peapods self-lend EXACT on RSS/$1200 rails (Morpho flash):
/// L1 flash USDC → L2 deposit fUSDC → L3 wrap RSS + LP pRSS/fUSDC
/// → L5 LP coll → L6 borrow USDC → L7 repay flash. Ends at ~100% vault util.
/// @dev Equal USD legs at $1200/RSS: rssAmt * 1200 * 1e6 == usdcAmt * 1e18
contract CrownPeapodsRssSelfLend is Ownable, ReentrancyGuard, IMorphoFlashCb {
    using SafeTransfer for IERC20;

    uint256 public constant RSS_USD = 1200;

    IMorphoFlash public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    CrownRssPodWrap public immutable pRss;
    CrownFusdVault public immutable vault;
    CrownPeapodsPair public immutable pair;
    IUniV2Router02 public immutable router;
    address public immutable king;
    address public immutable lpToken;

    bool private _locking;

    event PeapodsRssSelfLent(uint256 rssIn, uint256 usdcFlash, uint256 lpOut, uint256 borrowUsdc);

    error OnlyMorpho();
    error BadAmt();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address pRss_,
        address vault_,
        address pair_,
        address router_,
        address lp_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoFlash(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        pRss = CrownRssPodWrap(pRss_);
        vault = CrownFusdVault(vault_);
        pair = CrownPeapodsPair(pair_);
        router = IUniV2Router02(router_);
        lpToken = lp_;
        king = king_;
    }

    /// @param rssAmt RSS 18dp to wrap into LP (USD = rssAmt * 1200 / 1e18)
    /// @param usdcAmt USDC 6dp flash = fUSDC deposit = borrow (matched Peapods)
    function selfLend(uint256 rssAmt, uint256 usdcAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0 || usdcAmt == 0) revert BadAmt();
        if (rssAmt * RSS_USD * 1e6 != usdcAmt * 1e18) revert BadAmt();

        rss.safeTransferFrom(king, address(this), rssAmt);

        _locking = true;
        morpho.flashLoan(address(usdc), usdcAmt, abi.encode(rssAmt, usdcAmt));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 rssAmt, uint256 usdcAmt) = abi.decode(data, (uint256, uint256));
        if (assets != usdcAmt) revert BadAmt();

        usdc.safeApprove(address(vault), assets);
        uint256 fusdcShares = vault.deposit(assets, address(this));

        rss.safeApprove(address(pRss), rssAmt);
        uint256 pAmt = pRss.wrap(rssAmt);

        pRss.approve(address(router), pAmt);
        IERC20(address(vault)).approve(address(router), fusdcShares);
        (,, uint256 liq) = router.addLiquidity(
            address(pRss),
            address(vault),
            pAmt,
            fusdcShares,
            (pAmt * 95) / 100,
            (fusdcShares * 95) / 100,
            address(this),
            block.timestamp + 600
        );

        IERC20(lpToken).approve(address(pair), liq);
        pair.supplyCollateral(liq, king);

        pair.borrow(assets, king, address(this));

        usdc.safeApprove(address(morpho), assets);

        emit PeapodsRssSelfLent(rssAmt, assets, liq, assets);
    }
}
