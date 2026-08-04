// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFlash {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface ISeedFill {
    function fill(uint256 usdcIn) external returns (uint256 rssOut);
    function quoteRssOut(uint256 usdcIn) external view returns (uint256);
    function rssEscrow() external view returns (uint256);
}

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IAeroPair {
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function token0() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
}

/// @notice Do-the-impossible machine — lasting Landing USDC without a named desk.
/// @dev Paths (cold-or-revert on Landing delta):
///      1) extractDex — sell free RSS into live Aero depth → Landing (scales with pool).
///      2) flashFillExtract — Morpho flash → permissionless seed.fill → USDC to Landing
///         → sell RSS to repay flash. Net Landing ↑ only when seed sweetener + depth close.
///      Elepan never touched. Flash alone never counts as funded.
contract CrownImpossibleUsdcMachine is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFlash public immutable morpho;
    IAeroRouter public immutable aeroRouter;
    IAeroPair public immutable aeroPair;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable aeroFactory;
    address public immutable landing;
    address public constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;

    ISeedFill public seed;
    bool private _flashActive;
    uint256 private _flashAmt;
    uint256 private _minLandingGain;

    event DexExtract(uint256 rssIn, uint256 usdcOut);
    event FlashFillExtract(uint256 flashUsdc, uint256 rssFromSeed, uint256 usdcToLanding, uint256 rssSold);

    error Elepan();
    error LandingMiss();
    error Flash();
    error Depth();
    error Zero();

    constructor(
        address morpho_,
        address aeroRouter_,
        address aeroPair_,
        address aeroFactory_,
        address usdc_,
        address rss_,
        address landing_,
        address seed_,
        address owner_
    ) Ownable(owner_) {
        require(rss_ != ELEPAN, "ELEPAN");
        morpho = IMorphoFlash(morpho_);
        aeroRouter = IAeroRouter(aeroRouter_);
        aeroPair = IAeroPair(aeroPair_);
        aeroFactory = aeroFactory_;
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        landing = landing_;
        seed = ISeedFill(seed_);
    }

    function setSeed(address seed_) external onlyOwner {
        seed = ISeedFill(seed_);
    }

    /// @notice Max USDC extractable from Aero for a given RSS sell size (view).
    function quoteDexOut(uint256 rssIn) external view returns (uint256) {
        if (rssIn == 0) return 0;
        return aeroPair.getAmountOut(rssIn, address(rss));
    }

    /// @notice Path 1: sell `rssIn` free RSS (pulled from king) → USDC straight to Landing.
    function extractDex(uint256 rssIn, uint256 minUsdcOut) external onlyOwner nonReentrant returns (uint256 usdcOut) {
        if (rssIn == 0) revert Zero();
        uint256 before = usdc.balanceOf(landing);
        rss.safeTransferFrom(msg.sender, address(this), rssIn);
        usdcOut = _swapRssTo(landing, rssIn, minUsdcOut);
        if (usdc.balanceOf(landing) < before + usdcOut) revert LandingMiss();
        emit DexExtract(rssIn, usdcOut);
    }

    /// @notice Path 2: flash USDC → seed.fill (Landing+) → sell RSS to repay flash.
    /// @dev `rssSell` must be approved to this. Sizes so DEX out ≥ flash. Leftover USDC → Landing.
    function flashFillExtract(uint256 flashUsdc, uint256 rssSell, uint256 minLandingGain)
        external
        onlyOwner
        nonReentrant
    {
        if (flashUsdc == 0 || rssSell == 0) revert Zero();
        if (address(seed) == address(0)) revert Zero();
        uint256 q = aeroPair.getAmountOut(rssSell, address(rss));
        if (q < flashUsdc) revert Depth();

        rss.safeTransferFrom(msg.sender, address(this), rssSell);
        _flashActive = true;
        _flashAmt = flashUsdc;
        _minLandingGain = minLandingGain;
        morpho.flashLoan(address(usdc), flashUsdc, abi.encode(rssSell));
        _flashActive = false;
        _flashAmt = 0;
        _minLandingGain = 0;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_flashActive) revert Flash();
        if (assets != _flashAmt) revert Flash();
        uint256 rssSell = abi.decode(data, (uint256));

        uint256 landBefore = usdc.balanceOf(landing);

        // Approve seed + fill — USDC goes to Landing, RSS sweetener to this
        usdc.safeApprove(address(seed), 0);
        usdc.safeApprove(address(seed), assets);
        uint256 rssFromSeed = seed.fill(assets);

        // Sell RSS (pre-pulled) to raise flash repay; any surplus USDC → Landing
        uint256 got = _swapRssTo(address(this), rssSell, assets);
        if (got < assets) revert Depth();

        // Repay Morpho
        usdc.safeApprove(address(morpho), 0);
        usdc.safeApprove(address(morpho), assets);
        // Morpho pulls via transferFrom in flashLoan return path — leave approval

        // Surplus USDC + ensure Landing gained from seed fill
        uint256 surplus = usdc.balanceOf(address(this)) - assets;
        if (surplus > 0) usdc.safeTransfer(landing, surplus);

        // Forward seed RSS to owner (inventory), not recycled into Morpho
        uint256 rssBal = rss.balanceOf(address(this));
        if (rssBal > 0) rss.safeTransfer(owner, rssBal);

        uint256 landAfter = usdc.balanceOf(landing);
        if (landAfter < landBefore + _minLandingGain) revert LandingMiss();

        emit FlashFillExtract(assets, rssFromSeed, landAfter - landBefore, rssSell);
    }

    function _swapRssTo(address to, uint256 rssIn, uint256 minOut) internal returns (uint256 out) {
        if (rssIn == 0) revert Zero();
        rss.safeApprove(address(aeroRouter), 0);
        rss.safeApprove(address(aeroRouter), rssIn);
        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({
            from: address(rss),
            to: address(usdc),
            stable: false,
            factory: aeroFactory
        });
        uint256[] memory amts = aeroRouter.swapExactTokensForTokens(
            rssIn, minOut, routes, to, block.timestamp
        );
        out = amts[amts.length - 1];
    }

    function sweep(address token, uint256 amt, address to) external onlyOwner {
        if (token == ELEPAN) revert Elepan();
        if (to == address(0)) to = landing;
        if (amt == 0) amt = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, amt);
    }
}
