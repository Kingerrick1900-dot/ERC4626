// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {KingSusdc} from "./KingSusdc.sol";
import {KingPair} from "./KingPair.sol";
import {KingMoneyMarket} from "./KingMoneyMarket.sol";

interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

/// @notice Option A bootstrap funded by Aave V3 flashloan (Base).
/// @dev Correct loop (NOT swap-half cash LP):
///      flash F → supply all F as sUSDC → LP(RSS, sUSDC) → collateral → borrow F →
///      repay F+premium using borrow + prefunded premium on this contract.
///      Requires: 0.7*(rssUsd + F) >= F+premium and USDC balance (>= premium) before call.
contract KingPodAave is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    KingSusdc public immutable sUsdc;
    KingPair public immutable pair;
    KingMoneyMarket public immutable market;
    IAavePool public immutable aave;
    address public king;

    event Bootstrapped(address indexed king, uint256 rssUsed, uint256 flashUsdc, uint256 premium, uint256 lpMinted, uint256 debt);

    error OnlyAave();
    error BadInitiator();

    constructor(
        address rss_,
        address usdc_,
        address sUsdc_,
        address pair_,
        address market_,
        address aavePool_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        sUsdc = KingSusdc(sUsdc_);
        pair = KingPair(pair_);
        market = KingMoneyMarket(market_);
        aave = IAavePool(aavePool_);
        king = king_;
    }

    function setKing(address k) external onlyOwner {
        require(k != address(0), "ZERO");
        king = k;
    }

    /// @param rssAmount RSS from King (approve this pod). Example: 10e6 ether.
    /// @param flashUsdcAmount USDC flash (6 decimals). For 10M RSS @ $0.05, soft ≤ ~$1.16M.
    /// @dev Prefund this contract with ≥ premium USDC (Aave ~0.05%) before calling.
    function bootstrap(uint256 rssAmount, uint256 flashUsdcAmount) external onlyOwner nonReentrant {
        require(rssAmount > 0 && flashUsdcAmount > 0, "ZERO");
        bytes memory params = abi.encode(rssAmount, flashUsdcAmount, msg.sender);
        aave.flashLoanSimple(address(this), address(usdc), flashUsdcAmount, params, 0);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender != address(aave)) revert OnlyAave();
        if (initiator != address(this)) revert BadInitiator();
        require(asset == address(usdc), "ASSET");

        (uint256 rssAmount, uint256 flashAmount, address caller) = abi.decode(params, (uint256, uint256, address));
        require(caller == owner, "OWNER");
        require(amount == flashAmount, "AMT");

        uint256 repay = amount + premium;

        // Pull RSS from King
        rss.safeTransferFrom(king, address(this), rssAmount);

        // Option A: supply ALL flash USDC → sUSDC
        usdc.safeApprove(address(sUsdc), amount);
        uint256 sShares = sUsdc.deposit(amount, address(this));

        // LP(RSS, sUSDC)
        rss.safeTransfer(address(pair), rssAmount);
        require(sUsdc.transfer(address(pair), sShares), "sUSDC");
        uint256 lpMinted = pair.mint(address(this));

        // Collateral + borrow face amount (vault idle == amount). Premium paid from prefund.
        require(pair.transfer(address(market), lpMinted), "LP");
        market.creditCollateral(king, lpMinted);
        market.borrowTo(king, amount, address(this));

        uint256 bal = usdc.balanceOf(address(this));
        require(bal >= repay, "PREMIUM"); // borrow `amount` + prefunded premium

        usdc.safeApprove(address(aave), repay);
        emit Bootstrapped(king, rssAmount, amount, premium, lpMinted, amount);
        return true;
    }

    function rescue(address token, uint256 amt, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amt);
    }
}
