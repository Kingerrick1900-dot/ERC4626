// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface ILsrSellGem {
    function sellGem(uint256 usdcAmt) external returns (uint256 eusdOut);
    function usdcReserves() external view returns (uint256);
}

interface IMorphoFlash {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

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

/// @title CrownPSMFiller
/// @notice Atomic closer: USDC/USDT → LSR sellGem → USDC stays in PSM. Optional Morpho flash + UniV3 repay.
/// @dev Direct `fill` is the live door (sellGem). `flashFill` closes when eUSD→gem DEX exit covers repay+fee.
contract CrownPSMFiller is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    ILsrSellGem public immutable lsr;
    IMorphoFlash public immutable morpho;
    ISwapRouter02 public immutable router;
    IERC20 public immutable usdc;
    IERC20 public immutable usdt;
    IERC20 public immutable eusd;
    address public immutable hot;
    address public agent; // CrownKingAgent
    mapping(address => bool) public operator;

    uint24 public uniFee = 500; // eUSD/USDC 0.05% pool

    event AgentSet(address agent);
    event OperatorSet(address op, bool on);
    event UniFeeSet(uint24 fee);
    event Filled(address indexed gem, uint256 gemIn, uint256 eusdOut, uint256 lsrUsdc);
    event FlashFilled(address indexed gem, uint256 borrowed, uint256 eusdOut, uint256 lsrUsdc);

    error Auth();
    error Bad();
    error Flash();
    error Repay();

    modifier onlyAgentOrOp() {
        if (msg.sender != owner && msg.sender != hot && msg.sender != agent && !operator[msg.sender]) revert Auth();
        _;
    }

    constructor(
        address lsr_,
        address morpho_,
        address router_,
        address usdc_,
        address usdt_,
        address eusd_,
        address hot_,
        address owner_
    ) Ownable(owner_) {
        require(
            lsr_ != address(0) && morpho_ != address(0) && router_ != address(0) && usdc_ != address(0)
                && eusd_ != address(0) && hot_ != address(0),
            "ZERO"
        );
        lsr = ILsrSellGem(lsr_);
        morpho = IMorphoFlash(morpho_);
        router = ISwapRouter02(router_);
        usdc = IERC20(usdc_);
        usdt = IERC20(usdt_);
        eusd = IERC20(eusd_);
        hot = hot_;
    }

    function setAgent(address a) external onlyOwner {
        agent = a;
        emit AgentSet(a);
    }

    function setOperator(address op, bool on) external onlyOwner {
        operator[op] = on;
        emit OperatorSet(op, on);
    }

    function setUniFee(uint24 fee) external onlyOwner {
        uniFee = fee;
        emit UniFeeSet(fee);
    }

    /// @notice Pull gem (USDC/USDT) from caller → sellGem. Real gem stays in LSR.
    function fill(address gem, uint256 amt) external onlyAgentOrOp nonReentrant returns (uint256 eusdOut) {
        eusdOut = _fill(gem, amt, msg.sender);
    }

    /// @notice Morpho flash → sellGem → UniV3 eUSD→gem → repay. Reverts if exit can't cover repay.
    function flashFill(address gem, uint256 amt, uint256 minEusdOut)
        external
        onlyAgentOrOp
        nonReentrant
    {
        if (gem != address(usdc) && gem != address(usdt)) revert Bad();
        if (amt == 0) revert Bad();
        morpho.flashLoan(gem, amt, abi.encode(gem, minEusdOut, msg.sender));
    }

    /// @notice Morpho callback — only Morpho.
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Flash();
        (address gem, uint256 minEusdOut,) = abi.decode(data, (address, uint256, address));
        if (gem != address(usdc) && gem != address(usdt)) revert Bad();

        uint256 before = IERC20(gem).balanceOf(address(lsr));
        IERC20(gem).safeApprove(address(lsr), assets);
        uint256 eusdOut = lsr.sellGem(assets);
        if (eusdOut < minEusdOut) revert Bad();

        // Swap eUSD → gem to repay flash (+ Morpho 0 fee on flash; still need full assets back)
        uint256 need = assets;
        uint256 have = IERC20(gem).balanceOf(address(this));
        if (have < need) {
            uint256 still = need - have;
            eusd.safeApprove(address(router), eusdOut);
            uint256 got = router.exactInputSingle(
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: address(eusd),
                    tokenOut: gem,
                    fee: uniFee,
                    recipient: address(this),
                    amountIn: eusdOut,
                    amountOutMinimum: still,
                    sqrtPriceLimitX96: 0
                })
            );
            // leftover eUSD stays on filler for HOT sweep
            if (got < still && IERC20(gem).balanceOf(address(this)) < need) revert Repay();
        }

        IERC20(gem).safeApprove(address(morpho), need);
        uint256 after_ = IERC20(gem).balanceOf(address(lsr));
        emit FlashFilled(gem, assets, eusdOut, after_);
        if (after_ <= before) revert Bad(); // PSM must rise
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(hot, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }

    function _fill(address gem, uint256 amt, address from) internal returns (uint256 eusdOut) {
        if (gem != address(usdc) && gem != address(usdt)) revert Bad();
        if (amt == 0) revert Bad();
        uint256 before = IERC20(gem).balanceOf(address(lsr));
        IERC20(gem).safeTransferFrom(from, address(this), amt);
        IERC20(gem).safeApprove(address(lsr), amt);
        eusdOut = lsr.sellGem(amt);
        uint256 after_ = IERC20(gem).balanceOf(address(lsr));
        if (after_ <= before) revert Bad();
        // eUSD from sellGem sits on this contract — forward to hot
        uint256 eBal = eusd.balanceOf(address(this));
        if (eBal > 0) eusd.safeTransfer(hot, eBal);
        emit Filled(gem, amt, eusdOut, after_);
    }
}
