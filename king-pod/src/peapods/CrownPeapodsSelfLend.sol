// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownPodWrap} from "./CrownPodWrap.sol";
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

    function factory() external view returns (address);
}

interface IUniV2Factory {
    function getPair(address, address) external view returns (address);
    function createPair(address, address) external returns (address);
}

/// @notice Peapods self-lend EXACT 6-step on kingdom rails (Morpho flash):
/// L1 flash USDC → L2 deposit fUSDC vault → L3 wrap ELE + LP pELE/fUSDC
/// → L5 LP coll → L6 borrow USDC → L7 repay flash. Ends at ~100% vault util.
contract CrownPeapodsSelfLend is Ownable, ReentrancyGuard, IMorphoFlashCb {
    using SafeTransfer for IERC20;

    IMorphoFlash public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable ele;
    CrownPodWrap public immutable pEle;
    CrownFusdVault public immutable vault;
    CrownPeapodsPair public immutable pair;
    IUniV2Router02 public immutable router;
    address public immutable king;
    address public immutable lpToken;

    bool private _locking;

    event PeapodsSelfLent(uint256 eleIn, uint256 usdcFlash, uint256 lpOut, uint256 borrowUsdc);

    error OnlyMorpho();
    error BadAmt();

    constructor(
        address morpho_,
        address usdc_,
        address ele_,
        address pEle_,
        address vault_,
        address pair_,
        address router_,
        address lp_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoFlash(morpho_);
        usdc = IERC20(usdc_);
        ele = IERC20(ele_);
        pEle = CrownPodWrap(pEle_);
        vault = CrownFusdVault(vault_);
        pair = CrownPeapodsPair(pair_);
        router = IUniV2Router02(router_);
        lpToken = lp_;
        king = king_;
    }

    /// @param eleAmt ELE 8dp to wrap into LP
    /// @param usdcAmt USDC 6dp flash = fUSDC deposit = borrow (matched Peapods)
    function selfLend(uint256 eleAmt, uint256 usdcAmt) external onlyOwner nonReentrant {
        if (eleAmt == 0 || usdcAmt == 0) revert BadAmt();
        // Equal USD at soft $1: eleAmt/1e8 == usdcAmt/1e6
        if (eleAmt * 1e6 != usdcAmt * 1e8) revert BadAmt();

        ele.safeTransferFrom(king, address(this), eleAmt);

        _locking = true;
        morpho.flashLoan(address(usdc), usdcAmt, abi.encode(eleAmt, usdcAmt));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 eleAmt, uint256 usdcAmt) = abi.decode(data, (uint256, uint256));
        if (assets != usdcAmt) revert BadAmt();

        // L2 — supply pairing asset → fUSDC receipt
        usdc.safeApprove(address(vault), assets);
        uint256 fusdcShares = vault.deposit(assets, address(this));

        // L3 — wrap ELE → pELE, form LP with fUSDC
        ele.safeApprove(address(pEle), eleAmt);
        uint256 pAmt = pEle.wrap(eleAmt);

        pEle.approve(address(router), pAmt);
        IERC20(address(vault)).approve(address(router), fusdcShares);
        (,, uint256 liq) = router.addLiquidity(
            address(pEle),
            address(vault),
            pAmt,
            fusdcShares,
            (pAmt * 95) / 100,
            (fusdcShares * 95) / 100,
            address(this),
            block.timestamp + 600
        );

        // L5 — LP as collateral
        IERC20(lpToken).approve(address(pair), liq);
        pair.supplyCollateral(liq, king);

        // L6 — borrow pairing asset back (full flash; LTV on 2× fUSDC leg @ 50% = 100% of deposit)
        pair.borrow(assets, king, address(this));

        // L7 — repay flash
        usdc.safeApprove(address(morpho), assets);

        emit PeapodsSelfLent(eleAmt, assets, liq, assets);
    }
}
