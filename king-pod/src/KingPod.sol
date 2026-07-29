// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {KingSusdc} from "./KingSusdc.sol";
import {KingPair} from "./KingPair.sol";
import {KingMoneyMarket} from "./KingMoneyMarket.sol";

interface IFlashLoanRecipient {
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IBalancerVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

/// @notice Option A bootstrap: flash USDC → sUSDC → LP(RSS,sUSDC) → collateral → borrow → repay.
contract KingPod is Ownable, ReentrancyGuard, IFlashLoanRecipient {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    KingSusdc public immutable sUsdc;
    KingPair public immutable pair;
    KingMoneyMarket public immutable market;
    IBalancerVault public immutable balancer;

    address public king; // position owner (treasury)

    uint256 public constant LIQUID_RESERVE_RSS = 21_000_000 ether;

    event Bootstrapped(address indexed king, uint256 rssUsed, uint256 flashUsdc, uint256 lpMinted, uint256 debt);

    error OnlyBalancer();
    error BadInitiator();

    constructor(
        address rss_,
        address usdc_,
        address sUsdc_,
        address pair_,
        address market_,
        address balancer_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        sUsdc = KingSusdc(sUsdc_);
        pair = KingPair(pair_);
        market = KingMoneyMarket(market_);
        balancer = IBalancerVault(balancer_);
        king = king_;
    }

    function setKing(address k) external onlyOwner {
        require(k != address(0), "ZERO");
        king = k;
    }

    /// @param rssAmount RSS pulled from `king` (approve Pod first). Leave >= 21M liquid outside this call.
    /// @param flashUsdcAmount USDC flash amount (6 decimals).
    function bootstrap(uint256 rssAmount, uint256 flashUsdcAmount) external onlyOwner nonReentrant {
        require(rssAmount > 0 && flashUsdcAmount > 0, "ZERO");
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = usdc;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashUsdcAmount;
        bytes memory data = abi.encode(msg.sender, rssAmount, flashUsdcAmount);
        balancer.flashLoan(this, tokens, amounts, data);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        // Re-enters from Balancer while bootstrap() holds the guard — do not use nonReentrant here.
        if (msg.sender != address(balancer)) revert OnlyBalancer();
        require(tokens.length == 1 && address(tokens[0]) == address(usdc), "TOKEN");
        (address initiator, uint256 rssAmount, uint256 flashAmount) = abi.decode(userData, (address, uint256, uint256));
        if (initiator != owner) revert BadInitiator();
        require(amounts[0] == flashAmount, "AMT");

        uint256 fee = feeAmounts[0];
        uint256 repay = flashAmount + fee;

        // 1) Pull RSS from King
        rss.safeTransferFrom(king, address(this), rssAmount);

        // 2) Supply all flash USDC → sUSDC to this pod
        usdc.safeApprove(address(sUsdc), flashAmount);
        uint256 sShares = sUsdc.deposit(flashAmount, address(this));

        // 3) Add liquidity RSS + sUSDC
        rss.safeTransfer(address(pair), rssAmount);
        require(sUsdc.transfer(address(pair), sShares), "sUSDC");
        uint256 lpMinted = pair.mint(address(this));

        // 4) Post LP collateral for King
        require(pair.transfer(address(market), lpMinted), "LP");
        market.creditCollateral(king, lpMinted);

        // 5) Borrow repay amount to this pod
        market.borrowTo(king, repay, address(this));

        // 6) Repay Balancer
        usdc.safeTransfer(address(balancer), repay);

        emit Bootstrapped(king, rssAmount, flashAmount, lpMinted, repay);
    }
}
