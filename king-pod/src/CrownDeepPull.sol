// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMinterEusd {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData)
        external;
}

interface IFlashLoanRecipient {
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

/// @dev Uni V3 NonfungiblePositionManager
interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool);
}

interface IUniPool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    function tickSpacing() external view returns (int24);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}

/// @title CrownDeepPull
/// @notice Kingdom-owned Uni V3 eUSD/USDC depth. Mint eUSD (minter) against yRSS inventory gate,
///         pair with USDC into the pool, LP NFT to HOT.
/// @dev Flash path (Balancer): flash USDC → mint eUSD → mint LP → repay flash from HOT USDC reserve.
///      Net USDC left in pool = USDC the Kingdom commits (flash cannot print permanent USDC).
///      REPAY_SOURCE = HOT USDC (transferFrom) covering flash + Balancer fee.
contract CrownDeepPull is Ownable, ReentrancyGuard, IFlashLoanRecipient, IERC721Receiver {
    using SafeTransfer for IERC20;

    IBalancerVault public immutable balancer;
    INonfungiblePositionManager public immutable npm;
    IMinterEusd public immutable eusd;
    IERC20 public immutable usdc;
    IERC20 public immutable yrss;
    address public immutable hot;
    address public immutable pool;
    uint24 public immutable fee;

    uint256 public minYrssShares; // inventory gate before mint
    uint256 public lastTokenId;
    uint256 public totalUsdcSeeded;
    uint256 public totalEusdSeeded;

    bool private _locking;
    uint256 private _flashAmt;
    uint256 private _eusdMint;
    int24 private _tickLower;
    int24 private _tickUpper;

    event Deepened(uint256 tokenId, uint256 usdcIn, uint256 eusdIn, uint128 liquidity, uint256 flash);
    event MinYrss(uint256 shares);

    error Auth();
    error OnlyBal();
    error Bad();
    error Short();
    error NoInventory();
    error NotMinter();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address balancer_,
        address npm_,
        address eusd_,
        address usdc_,
        address yrss_,
        address hot_,
        address pool_,
        uint24 fee_,
        uint256 minYrssShares_,
        address owner_
    ) Ownable(owner_) {
        balancer = IBalancerVault(balancer_);
        npm = INonfungiblePositionManager(npm_);
        eusd = IMinterEusd(eusd_);
        usdc = IERC20(usdc_);
        yrss = IERC20(yrss_);
        hot = hot_;
        pool = pool_;
        fee = fee_;
        minYrssShares = minYrssShares_;
    }

    function setMinYrssShares(uint256 shares) external onlyOwner {
        minYrssShares = shares;
        emit MinYrss(shares);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Seed pool with Kingdom USDC + freshly minted eUSD. No flash.
    /// @dev HOT must approve USDC. This contract must be eUSD minter. yRSS inventory gate.
    function seed(uint256 usdcAmt, uint256 eusdAmt, int24 tickLower, int24 tickUpper)
        external
        onlyHot
        nonReentrant
        returns (uint256 tokenId)
    {
        _requireInventory();
        if (usdcAmt == 0 || eusdAmt == 0) revert Bad();
        if (!eusd.isMinter(address(this))) revert NotMinter();

        usdc.safeTransferFrom(hot, address(this), usdcAmt);
        eusd.mint(address(this), eusdAmt);
        tokenId = _mintLp(usdcAmt, eusdAmt, tickLower, tickUpper, 0);
    }

    /// @notice Atomic flash deep-pull. REPAY_SOURCE = HOT USDC (≥ flash+fee).
    /// @dev Net pool USDC = usdcIntoPool. Flash size can equal usdcIntoPool; HOT pays repay.
    ///      `eusdAmt` minted in callback. LP to HOT.
    function deepPull(
        uint256 flashUsdc,
        uint256 usdcIntoPool,
        uint256 eusdAmt,
        int24 tickLower,
        int24 tickUpper
    ) external onlyHot nonReentrant returns (uint256 tokenId) {
        _requireInventory();
        if (flashUsdc == 0 || usdcIntoPool == 0 || eusdAmt == 0) revert Bad();
        if (!eusd.isMinter(address(this))) revert NotMinter();

        // HOT prefunds repay (flash + max fee cushion pulled inside callback accounting)
        // Pull repay capital up front so Balancer fee cannot strand the tx.
        usdc.safeTransferFrom(hot, address(this), flashUsdc); // equity / repay reserve
        // Extra into-pool USDC beyond flash also from HOT
        if (usdcIntoPool > flashUsdc) {
            usdc.safeTransferFrom(hot, address(this), usdcIntoPool - flashUsdc);
        }

        _flashAmt = flashUsdc;
        _eusdMint = eusdAmt;
        _tickLower = tickLower;
        _tickUpper = tickUpper;
        _locking = true;

        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashUsdc;
        balancer.flashLoan(address(this), tokens, amounts, abi.encode(usdcIntoPool));

        _locking = false;
        tokenId = lastTokenId;
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        if (msg.sender != address(balancer)) revert OnlyBal();
        if (!_locking) revert OnlyBal();
        if (tokens.length != 1 || tokens[0] != address(usdc)) revert Bad();

        uint256 flash = amounts[0];
        uint256 balFee = feeAmounts[0];
        uint256 due = flash + balFee;
        uint256 usdcIntoPool = abi.decode(userData, (uint256));
        if (flash != _flashAmt) revert Bad();

        // Balances: repay reserve (flashUsdc from HOT) + flashed USDC (+ optional extra)
        uint256 have = usdc.balanceOf(address(this));
        if (have < due + usdcIntoPool) revert Short();

        eusd.mint(address(this), _eusdMint);
        _mintLp(usdcIntoPool, _eusdMint, _tickLower, _tickUpper, flash);

        // Repay Balancer — REPAY_SOURCE = HOT USDC reserve held on this contract
        uint256 left = usdc.balanceOf(address(this));
        if (left < due) revert Short();
        usdc.safeTransfer(address(balancer), due);

        // Any spare USDC back to HOT
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(hot, dust);
    }

    function _requireInventory() internal view {
        if (yrss.balanceOf(hot) < minYrssShares) revert NoInventory();
    }

    function _mintLp(uint256 usdcAmt, uint256 eusdAmt, int24 tickLower, int24 tickUpper, uint256 flashTag)
        internal
        returns (uint256 tokenId)
    {
        address t0 = IUniPool(pool).token0(); // USDC
        address t1 = IUniPool(pool).token1(); // eUSD
        if (t0 != address(usdc) || t1 != address(eusd)) revert Bad();

        int24 spacing = IUniPool(pool).tickSpacing();
        tickLower = _floorTick(tickLower, spacing);
        tickUpper = _floorTick(tickUpper, spacing);
        if (tickLower >= tickUpper) revert Bad();

        IERC20 usdcT = usdc;
        IERC20 eusdT = IERC20(address(eusd));
        usdcT.safeApprove(address(npm), usdcAmt);
        eusdT.safeApprove(address(npm), eusdAmt);

        uint128 liq;
        uint256 a0;
        uint256 a1;
        (tokenId, liq, a0, a1) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: t0,
                token1: t1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: usdcAmt,
                amount1Desired: eusdAmt,
                amount0Min: 0,
                amount1Min: 0,
                recipient: hot,
                deadline: block.timestamp
            })
        );

        usdcT.safeApprove(address(npm), 0);
        eusdT.safeApprove(address(npm), 0);

        // Refund unused eUSD to HOT. USDC leftovers handled by seed/flash callers.
        uint256 eLeft = eusdT.balanceOf(address(this));
        if (eLeft > 0) eusdT.safeTransfer(hot, eLeft);

        lastTokenId = tokenId;
        totalUsdcSeeded += a0;
        totalEusdSeeded += a1;
        emit Deepened(tokenId, a0, a1, liq, flashTag);
    }

    function _floorTick(int24 tick, int24 spacing) internal pure returns (int24) {
        int24 compressed = tick / spacing;
        if (tick < 0 && tick % spacing != 0) compressed--;
        return compressed * spacing;
    }
}
