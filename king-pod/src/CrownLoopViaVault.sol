// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoVia {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IMorphoFlashLoanCallbackVia {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoVia {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @title CrownLoopViaVault
/// @notice Vault-routed Morpho flash seed — USDC goes through ySYNTH, not around it.
/// @dev FIX for CrownLoopNative ghost path:
///      OLD: flash → morpho.supply(onBehalf=king) → vault sees $0
///      NEW: flash → ySYNTH.deposit(receiver=king) → vault owns Morpho supply shares
///           → king borrows idle against eUSD → repay flash
///      Verify after fire: ySYNTH.balanceOf(king) > 0 and ySYNTH.totalAssets rose.
/// @notice DO NOT scale until a controlled small fire proves vault share ownership.
contract CrownLoopViaVault is Ownable, ReentrancyGuard, IMorphoFlashLoanCallbackVia {
    using SafeTransfer for IERC20;

    IMorphoVia public immutable morpho;
    IMetaMorphoVia public immutable vault; // ySYNTH-USDC
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoVia.MarketParams public mp;

    bool private _locking;
    bool public armed;
    uint256 public maxFlash; // hard cap — King sets before any fire
    uint256 public totalFlashed;
    uint256 public totalDeposited;
    uint256 public fires;

    event Armed(bool on);
    event MaxFlash(uint256 cap);
    event Looped(uint256 flashUsdc, uint256 deposited, uint256 vaultShares, uint256 borrowUsdc, uint256 fireId);

    error OnlyMorpho();
    error BadAmt();
    error Idle();
    error Auth();
    error Disarmed();
    error Cap();
    error VaultAsset();

    modifier onlyKing() {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    constructor(
        address morpho_,
        address vault_,
        address usdc_,
        address eusd_,
        address king_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoVia(morpho_);
        vault = IMetaMorphoVia(vault_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        king = king_;
        if (IMetaMorphoVia(vault_).asset() != usdc_) revert VaultAsset();
        mp = IMorphoVia.MarketParams({
            loanToken: usdc_,
            collateralToken: eusd_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        marketId = keccak256(abi.encode(mp));
        maxFlash = 1e6; // default $1 — must raise explicitly to scale
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setMaxFlash(uint256 cap) external onlyOwner {
        maxFlash = cap;
        emit MaxFlash(cap);
    }

    /// @notice Controlled fire. Caps at maxFlash. Routes USDC through vault.deposit.
    function fire(uint256 flashUsdc, uint256 eusdColl) external onlyKing nonReentrant {
        if (!armed) revert Disarmed();
        if (flashUsdc < 1e6) revert BadAmt();
        if (flashUsdc > maxFlash) revert Cap();
        if (eusdColl == 0) revert BadAmt();
        if (flashUsdc * 1e12 * 1e18 > eusdColl * mp.lltv) revert BadAmt();

        eusd.safeTransferFrom(king, address(this), eusdColl);
        eusd.approve(address(morpho), eusdColl);
        morpho.supplyCollateral(mp, eusdColl, king, "");

        _locking = true;
        morpho.flashLoan(address(usdc), flashUsdc, abi.encode(flashUsdc));
        _locking = false;

        totalFlashed += flashUsdc;
        unchecked {
            ++fires;
        }
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        uint256 flashUsdc = abi.decode(data, (uint256));
        if (assets != flashUsdc) revert BadAmt();

        // 1) Deposit flashed USDC INTO the vault — vault supplies Morpho; king gets shares
        usdc.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, king);
        totalDeposited += assets;

        // 2) Borrow the new idle against king's eUSD to close the flash
        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert Idle();

        morpho.borrow(mp, assets, 0, king, address(this));

        // 3) Repay flash (fee 0)
        usdc.approve(address(morpho), assets);
        emit Looped(assets, assets, shares, assets, fires + 1);
    }
}
