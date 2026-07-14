// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {CrownFlashRouter, ICrownFlashBorrower} from "./CrownFlashRouter.sol";

/// @notice Uni V3 fee-tier arb borrower backed by CrownFlashRouter (Morpho 0% → 5 bps to King).
contract CrownFlashArb is Ownable, ReentrancyGuard, ICrownFlashBorrower {
    using SafeTransfer for IERC20;

    CrownFlashRouter public immutable router;
    IERC20 public immutable usdc;
    address public treasury;
    address public operator;

    event ArbitrageExecuted(uint256 amountIn, uint256 fee, uint256 profit);
    event OperatorUpdated(address operator);
    event TreasuryUpdated(address treasury);

    error NotRouter();
    error NotAuthorized();
    error SwapFailed();
    error ProfitTooLow();

    constructor(address router_, address usdc_, address treasury_, address owner_, address operator_) Ownable(owner_) {
        require(router_ != address(0) && usdc_ != address(0) && treasury_ != address(0), "ZERO");
        router = CrownFlashRouter(router_);
        usdc = IERC20(usdc_);
        treasury = treasury_;
        operator = operator_;
    }

    modifier onlyOperatorOrOwner() {
        if (msg.sender != operator && msg.sender != owner) revert NotAuthorized();
        _;
    }

    function setOperator(address o) external onlyOwner {
        require(o != address(0), "ZERO");
        operator = o;
        emit OperatorUpdated(o);
    }

    function setTreasury(address t) external onlyOwner {
        require(t != address(0), "ZERO");
        treasury = t;
        emit TreasuryUpdated(t);
    }

    /// @notice Kick Morpho flash via Crown router; swaps encoded in data.
    function flashArbitrage(
        uint256 amountIn,
        address routerBuy,
        bytes calldata swapDataBuy,
        address routerSell,
        bytes calldata swapDataSell,
        uint256 minProfit
    ) external onlyOperatorOrOwner {
        // Do NOT nonReentrant here — CrownFlashRouter callbacks into onCrownFlash in the same tx.
        bytes memory data = abi.encode(routerBuy, swapDataBuy, routerSell, swapDataSell, minProfit);
        router.flashLoan(amountIn, data);
    }

    function onCrownFlash(uint256 assets, uint256 fee, bytes calldata data) external override nonReentrant {
        if (msg.sender != address(router)) revert NotRouter();
        _exec(assets, fee, data);
    }

    function _exec(uint256 assets, uint256 fee, bytes calldata data) internal {
        (address routerBuy, bytes memory swapDataBuy, address routerSell, bytes memory swapDataSell, uint256 minProfit) =
            abi.decode(data, (address, bytes, address, bytes, uint256));

        usdc.safeApprove(routerBuy, assets);
        (bool okBuy,) = routerBuy.call(swapDataBuy);
        if (!okBuy) revert SwapFailed();

        // Mid asset is encoded as first 20 bytes of sell calldata prefix isn't available —
        // approve WETH if present (live Base), else skip for mock/tests.
        address weth = 0x4200000000000000000000000000000000000006;
        (bool okMid, bytes memory ret) = weth.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, address(this)));
        if (okMid && ret.length >= 32) {
            uint256 midBal = abi.decode(ret, (uint256));
            if (midBal > 0) IERC20(weth).safeApprove(routerSell, midBal);
        }

        (bool okSell,) = routerSell.call(swapDataSell);
        if (!okSell) revert SwapFailed();

        uint256 repay = assets + fee;
        uint256 bal = usdc.balanceOf(address(this));
        if (bal < repay + minProfit) revert ProfitTooLow();

        usdc.safeApprove(address(router), repay);
        unchecked {
            bal = bal - repay;
        }
        if (bal > 0) usdc.safeTransfer(treasury, bal);
        emit ArbitrageExecuted(assets, fee, bal);
    }

    function rescue(address token, uint256 amt, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amt);
    }
}
