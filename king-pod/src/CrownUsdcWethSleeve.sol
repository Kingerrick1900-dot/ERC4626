// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IERC4626Y {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function asset() external view returns (address);
}

/// @notice USDC → WETH swap sleeve → deposit into yELEPAN MetaMorpho / VaultV2.
/// @dev Allocator on destination vaults. Pulls USDC from `from` (FHE vault) or msg.sender.
contract CrownUsdcWethSleeve is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable weth;
    ISwapRouter02 public immutable router;
    uint24 public poolFee = 500; // Uni V3 USDC/WETH 0.05% on Base
    uint256 public maxSlippageBps = 100; // 1% floor vs spot oracle optional; minOut from caller

    address public yMorpho; // MetaMorpho WETH vault
    address public yVaultV2; // Vault V2 WETH
    address public fheVault; // CrownFhePrivateVault (USDC)

    event Routed(address indexed from, uint256 usdcIn, uint256 wethOut, uint256 toMorpho, uint256 toV2);
    event DestSet(address yMorpho, address yVaultV2, address fheVault);
    event PoolFee(uint24 fee);

    error BadAmt();
    error BadDest();

    constructor(
        address usdc_,
        address weth_,
        address router_,
        address yMorpho_,
        address yVaultV2_,
        address fheVault_,
        address owner_
    ) Ownable(owner_) {
        usdc = IERC20(usdc_);
        weth = IERC20(weth_);
        router = ISwapRouter02(router_);
        yMorpho = yMorpho_;
        yVaultV2 = yVaultV2_;
        fheVault = fheVault_;
    }

    function setDest(address yMorpho_, address yVaultV2_, address fheVault_) external onlyOwner {
        yMorpho = yMorpho_;
        yVaultV2 = yVaultV2_;
        fheVault = fheVault_;
        emit DestSet(yMorpho_, yVaultV2_, fheVault_);
    }

    function setPoolFee(uint24 fee) external onlyOwner {
        poolFee = fee;
        emit PoolFee(fee);
    }

    function setMaxSlippageBps(uint256 bps) external onlyOwner {
        if (bps > 1000) revert BadAmt();
        maxSlippageBps = bps;
    }

    /// @notice Pull `usdcIn` from `from`, swap to WETH, split deposit to Morpho / V2 (bps of WETH out).
    /// @param morphoBps share of WETH to MetaMorpho (rest → V2). 10000 = all Morpho.
    /// @dev Callable by owner or the configured FHE vault (allocate path).
    function route(address from, uint256 usdcIn, uint256 minWethOut, uint256 morphoBps)
        external
        nonReentrant
        returns (uint256 wethOut)
    {
        if (msg.sender != owner && msg.sender != fheVault) revert BadDest();
        if (usdcIn == 0 || morphoBps > 10_000) revert BadAmt();
        if (yMorpho == address(0) && yVaultV2 == address(0)) revert BadDest();

        usdc.safeTransferFrom(from, address(this), usdcIn);
        usdc.safeApprove(address(router), usdcIn);

        wethOut = router.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(weth),
                fee: poolFee,
                recipient: address(this),
                amountIn: usdcIn,
                amountOutMinimum: minWethOut,
                sqrtPriceLimitX96: 0
            })
        );
        if (wethOut == 0) revert BadAmt();

        uint256 toMorpho = wethOut * morphoBps / 10_000;
        uint256 toV2 = wethOut - toMorpho;

        if (toMorpho > 0) {
            if (yMorpho == address(0)) revert BadDest();
            weth.safeApprove(yMorpho, toMorpho);
            IERC4626Y(yMorpho).deposit(toMorpho, from); // shares to FHE vault / capital source
        }
        if (toV2 > 0) {
            if (yVaultV2 == address(0)) revert BadDest();
            weth.safeApprove(yVaultV2, toV2);
            IERC4626Y(yVaultV2).deposit(toV2, from);
        }

        emit Routed(from, usdcIn, wethOut, toMorpho, toV2);
    }

    function rescue(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(owner, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
