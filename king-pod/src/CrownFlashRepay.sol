// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IBalancerVault {
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData)
        external;
}

interface IFlashLoanRecipient {
    function receiveFlashLoan(address[] memory tokens, uint256[] memory amounts, uint256[] memory feeAmounts, bytes memory userData)
        external;
}

interface IMorphoFR {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function withdraw(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoFR {
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
}

/// @title CrownFlashRepay
/// @notice Balancer flash → repay Morpho borrow → withdraw supply → repay flash → remainder to HOT.
contract CrownFlashRepay is Ownable, ReentrancyGuard, IFlashLoanRecipient {
    using SafeTransfer for IERC20;

    IBalancerVault public immutable balancer;
    IMorphoFR public immutable morpho;
    IMetaMorphoFR public immutable vault;
    IERC20 public immutable usdc;
    address public immutable hot;
    bytes32 public immutable marketId;
    IMorphoFR.MarketParams public mp;

    bool private _locking;

    event Fired(uint256 flash, uint256 repaid, uint256 withdrawn, uint256 toHot);

    error Auth();
    error OnlyBal();
    error Bad();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address balancer_,
        address morpho_,
        address vault_,
        address usdc_,
        address eusd_,
        address hot_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        balancer = IBalancerVault(balancer_);
        morpho = IMorphoFR(morpho_);
        vault = IMetaMorphoFR(vault_);
        usdc = IERC20(usdc_);
        hot = hot_;
        mp = IMorphoFR.MarketParams(usdc_, eusd_, oracle_, irm_, lltv_);
        marketId = keccak256(abi.encode(mp));
    }

    function borrowAssets(address user) public view returns (uint256) {
        (, uint128 borShares,) = morpho.position(marketId, user);
        if (borShares == 0) return 0;
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        if (tbs == 0) return 0;
        return (uint256(borShares) * uint256(tba) + uint256(tbs) - 1) / uint256(tbs);
    }

    function supplyAssets(address user) public view returns (uint256) {
        (uint256 supShares,,) = morpho.position(marketId, user);
        if (supShares == 0) return 0;
        (uint128 tsa, uint128 tss,,,,) = morpho.market(marketId);
        if (tss == 0) return 0;
        return (uint256(supShares) * uint256(tsa)) / uint256(tss);
    }

    /// @notice One tx: flash Balancer USDC → repay HOT Morpho debt → withdraw → repay flash → dust to HOT.
    /// @dev If debt == 0, redeems max ySYNTH shares to HOT (idle path; no flash).
    function fire() external onlyHot nonReentrant {
        uint256 debt = borrowAssets(hot);
        if (debt == 0) {
            uint256 shares = vault.maxRedeem(hot);
            uint256 out;
            if (shares > 0) out = vault.redeem(shares, hot, hot);
            emit Fired(0, 0, out, out);
            return;
        }

        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = debt;

        _locking = true;
        balancer.flashLoan(address(this), tokens, amounts, abi.encode(debt));
        _locking = false;

        uint256 rem = usdc.balanceOf(address(this));
        if (rem > 0) usdc.safeTransfer(hot, rem);
        emit Fired(debt, debt, rem, rem);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external override {
        if (msg.sender != address(balancer)) revert OnlyBal();
        if (!_locking) revert OnlyBal();
        if (tokens.length != 1 || tokens[0] != address(usdc)) revert Bad();

        uint256 flash = amounts[0];
        uint256 fee = feeAmounts[0];
        uint256 due = flash + fee;

        usdc.approve(address(morpho), flash);

        (, uint128 borShares,) = morpho.position(marketId, hot);
        if (borShares > 0) {
            morpho.repay(mp, 0, borShares, hot, "");
        }

        (uint256 supShares,,) = morpho.position(marketId, hot);
        if (supShares > 0) {
            morpho.withdraw(mp, 0, supShares, hot, address(this));
        }

        // Also pull vault idle if redeemable by this contract (none expected)
        uint256 bal = usdc.balanceOf(address(this));
        if (bal < due) revert Bad();
        usdc.safeTransfer(address(balancer), due);
    }
}
