// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateFhe {
    function isProven(address subject) external view returns (bool);
    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

/// @notice Institutional private lending rail — ZK-gated now; FHE encrypted balances hook next.
/// @dev Pattern: Steakhouse/Morpho confidentiality model. Lenders supply USDC; shares track claims.
///      `encBalance` reserved for Zama fhEVM ciphertext handles (opaque bytes32 until FHE live on Base).
///      Performance fee 10% of yield accrual skimmed to feeRecipient (King).
contract CrownFhePrivateVault is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable asset; // USDC
    IZkGateFhe public immutable gate;
    address public feeRecipient;
    address public yVault; // optional MetaMorpho / VaultV2 sink for allocated liquidity
    uint256 public performanceFeeBps = 1000; // 10%
    uint256 public totalShares;
    uint256 public totalAssetsStored;

    mapping(address => uint256) public sharesOf;
    /// @dev Placeholder for Zama FHE ciphertext handle per depositor (unset until FHE wired).
    mapping(address => bytes32) public encBalance;

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event FeeSkimmed(uint256 feeAssets);
    event EncBalanceSet(address indexed user, bytes32 handle);
    event YVaultSet(address yVault);
    event FeeRecipientSet(address feeRecipient);

    error BadAmt();
    error NotProven();
    error Insolvent();

    constructor(address asset_, address gate_, address feeRecipient_, address owner_) Ownable(owner_) {
        asset = IERC20(asset_);
        gate = IZkGateFhe(gate_);
        feeRecipient = feeRecipient_;
    }

    function setYVault(address y) external onlyOwner {
        yVault = y;
        emit YVaultSet(y);
    }

    function setFeeRecipient(address r) external onlyOwner {
        if (r == address(0)) revert BadAmt();
        feeRecipient = r;
        emit FeeRecipientSet(r);
    }

    function setPerformanceFeeBps(uint256 bps) external onlyOwner {
        if (bps > 2000) revert BadAmt(); // hard cap 20%
        performanceFeeBps = bps;
    }

    /// @notice Open supply — institutions deposit USDC. Proven King ops gated separately.
    function deposit(uint256 assets) external nonReentrant returns (uint256 shares) {
        if (assets == 0) revert BadAmt();
        _skimFee();
        uint256 ta = totalAssets();
        shares = totalShares == 0 ? assets : assets * totalShares / ta;
        if (shares == 0) revert BadAmt();
        asset.safeTransferFrom(msg.sender, address(this), assets);
        sharesOf[msg.sender] += shares;
        totalShares += shares;
        totalAssetsStored = ta + assets;
        emit Deposit(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external nonReentrant returns (uint256 assets) {
        if (shares == 0 || shares > sharesOf[msg.sender]) revert BadAmt();
        _skimFee();
        uint256 ta = totalAssets();
        assets = shares * ta / totalShares;
        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        totalAssetsStored = ta - assets;
        asset.safeTransfer(msg.sender, assets);
        emit Withdraw(msg.sender, assets, shares);
    }

    /// @notice King-only: push idle USDC into configured yVault (MetaMorpho/V2) when wired.
    function allocateToYVault(uint256 assets) external onlyOwner nonReentrant {
        if (yVault == address(0) || assets == 0) revert BadAmt();
        if (!gate.isProven(msg.sender)) revert NotProven();
        asset.safeApprove(yVault, assets);
        // ERC4626 deposit — yVault must be ERC4626 USDC or adapter; WETH vault needs swap rail (future).
        (bool ok,) = yVault.call(abi.encodeWithSignature("deposit(uint256,address)", assets, address(this)));
        require(ok, "YVAULT_DEPOSIT");
    }

    /// @notice FHE hook: store ciphertext handle without revealing balance (Zama fhEVM when Base-ready).
    function setEncBalance(bytes32 handle) external {
        encBalance[msg.sender] = handle;
        emit EncBalanceSet(msg.sender, handle);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function _skimFee() internal {
        uint256 bal = asset.balanceOf(address(this));
        if (bal <= totalAssetsStored || totalShares == 0) {
            totalAssetsStored = bal;
            return;
        }
        uint256 profit = bal - totalAssetsStored;
        uint256 fee = profit * performanceFeeBps / 10_000;
        if (fee > 0) {
            asset.safeTransfer(feeRecipient, fee);
            emit FeeSkimmed(fee);
        }
        totalAssetsStored = asset.balanceOf(address(this));
    }
}
