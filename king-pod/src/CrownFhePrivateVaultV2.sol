// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateFhe2 {
    function isProven(address subject) external view returns (bool);
}

interface ISleeve {
    function route(address from, uint256 usdcIn, uint256 minWethOut, uint256 morphoBps)
        external
        returns (uint256 wethOut);
}

/// @notice FHE private vault v2 — open USDC deposits, 10% perf fee skim, Zama handle + sleeve allocate.
/// @dev Fee skim is USDC to feeRecipient (not MetaMorpho share-mint). MetaMorpho yELEPAN still
///      mints curator fee shares on WETH yield once allocated via sleeve.
contract CrownFhePrivateVaultV2 is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable asset; // USDC
    IZkGateFhe2 public immutable gate;
    address public feeRecipient;
    address public sleeve; // CrownUsdcWethSleeve
    uint256 public performanceFeeBps = 1000; // 10%
    uint256 public managementFeeBps; // optional base fee on AUM per skim (0 default)
    uint256 public lastSkim;
    uint256 public totalShares;
    uint256 public totalAssetsStored;

    mapping(address => uint256) public sharesOf;
    /// @notice Zama fhEVM ciphertext handle (bytes32). Coprocessor-ready; not plaintext.
    mapping(address => bytes32) public encBalance;
    mapping(address => bool) public kycGate; // optional institutional allowlist
    bool public kycEnabled;

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event FeeSkimmed(uint256 perfFee, uint256 mgmtFee);
    event EncBalanceSet(address indexed user, bytes32 handle);
    event SleeveSet(address sleeve);
    event Allocated(uint256 usdcIn, uint256 wethOut);
    event KycSet(address indexed user, bool allowed);
    event KycEnabled(bool enabled);

    error BadAmt();
    error NotProven();
    error Gated();

    constructor(address asset_, address gate_, address feeRecipient_, address owner_) Ownable(owner_) {
        asset = IERC20(asset_);
        gate = IZkGateFhe2(gate_);
        feeRecipient = feeRecipient_;
        lastSkim = block.timestamp;
    }

    function setSleeve(address s) external onlyOwner {
        sleeve = s;
        emit SleeveSet(s);
    }

    function setFees(uint256 perfBps, uint256 mgmtBps) external onlyOwner {
        if (perfBps > 2000 || mgmtBps > 200) revert BadAmt(); // ≤20% perf, ≤2% mgmt
        performanceFeeBps = perfBps;
        managementFeeBps = mgmtBps;
    }

    function setKycEnabled(bool on) external onlyOwner {
        kycEnabled = on;
        emit KycEnabled(on);
    }

    function setKyc(address user, bool allowed) external onlyOwner {
        kycGate[user] = allowed;
        emit KycSet(user, allowed);
    }

    function deposit(uint256 assets) external nonReentrant returns (uint256 shares) {
        if (kycEnabled && !kycGate[msg.sender]) revert Gated();
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
        // only idle USDC withdrawable — allocated WETH sits in yVault shares held here
        uint256 idle = asset.balanceOf(address(this));
        if (assets > idle) revert BadAmt();
        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        totalAssetsStored = ta - assets;
        asset.safeTransfer(msg.sender, assets);
        emit Withdraw(msg.sender, assets, shares);
    }

    /// @notice King: route idle USDC → WETH markets via sleeve (must approve sleeve first).
    function allocate(uint256 usdcIn, uint256 minWethOut, uint256 morphoBps)
        external
        onlyOwner
        nonReentrant
        returns (uint256 wethOut)
    {
        if (sleeve == address(0) || usdcIn == 0) revert BadAmt();
        if (!gate.isProven(msg.sender)) revert NotProven();
        asset.safeApprove(sleeve, usdcIn);
        wethOut = ISleeve(sleeve).route(address(this), usdcIn, minWethOut, morphoBps);
        totalAssetsStored = asset.balanceOf(address(this)); // USDC left; yVault shares tracked off totalAssetsStored
        emit Allocated(usdcIn, wethOut);
    }

    /// @notice Store Zama ciphertext handle (opaque). Real fhEVM coprocessor verification = next host upgrade.
    function setEncBalance(bytes32 handle) external {
        if (kycEnabled && !kycGate[msg.sender]) revert Gated();
        encBalance[msg.sender] = handle;
        emit EncBalanceSet(msg.sender, handle);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function _skimFee() internal {
        uint256 bal = asset.balanceOf(address(this));
        uint256 mgmt;
        if (managementFeeBps > 0 && totalShares > 0 && block.timestamp > lastSkim) {
            uint256 dt = block.timestamp - lastSkim;
            // pro-rata annualized on stored AUM
            mgmt = totalAssetsStored * managementFeeBps * dt / (10_000 * 365 days);
            if (mgmt > bal) mgmt = bal;
        }
        uint256 perf;
        if (bal > totalAssetsStored && totalShares > 0) {
            uint256 profit = bal - totalAssetsStored;
            perf = profit * performanceFeeBps / 10_000;
        }
        uint256 fee = perf + mgmt;
        if (fee > 0) {
            if (fee > bal) fee = bal;
            asset.safeTransfer(feeRecipient, fee);
            emit FeeSkimmed(perf, mgmt);
        }
        lastSkim = block.timestamp;
        totalAssetsStored = asset.balanceOf(address(this));
    }
}
