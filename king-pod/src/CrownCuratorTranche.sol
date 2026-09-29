// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IERC4626C {
    function asset() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IBordersC {
    function bordersSecure() external view returns (bool);
}

/// @title CrownCuratorTranche
/// @notice Cap $200M USDC into Gauntlet/Steakhouse MetaMorpho (+ optional Pendle PT sleeve).
/// @dev Asset is USDC only. Idle eUSD on Landing is NOT depositable here — convert via fills first.
///      Hard law: CAP = 200e6 USDC; cold eUSD war chest stays untouched on Landing.
contract CrownCuratorTranche is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant CAP = 200_000_000e6; // $200M USDC (6dp)
    uint256 public constant BPS = 10_000;

    IERC20 public immutable usdc;
    address public immutable hot;
    address public immutable harvestSink; // Scroll/Landing yield sink

    address public gauntlet; // Gauntlet USDC Prime
    address public steakhouse; // Steakhouse Prime USDC
    address public pendleSleeve; // optional PT holder / adapter (ERC4626-like or share token)
    address public attest;

    uint16 public gauntletBps = 4500; // 45%
    uint16 public steakBps = 4500; // 45%
    uint16 public pendleBps = 1000; // 10% (~$20M of $200M)

    uint256 public totalDeployed; // USDC principal accounted into curators/sleeve
    bool public requireBorders = true;
    bool public armed;

    mapping(address => bool) public operator;

    event Armed(bool on);
    event CuratorsSet(address gauntlet, address steakhouse, address pendle);
    event WeightsSet(uint16 g, uint16 s, uint16 p);
    event Deployed(uint256 usdcIn, uint256 toG, uint256 toS, uint256 toP);
    event Harvested(uint256 usdcOut, address sink);
    event OperatorSet(address op, bool on);

    error Auth();
    error Borders();
    error Bad();
    error Cap();
    error NotUsdcVault();
    error Disarmed();

    modifier onlyOp() {
        if (msg.sender != owner && msg.sender != hot && !operator[msg.sender]) revert Auth();
        _;
    }

    constructor(address usdc_, address hot_, address harvestSink_, address owner_) Ownable(owner_) {
        if (usdc_ == address(0) || hot_ == address(0) || harvestSink_ == address(0)) revert Bad();
        usdc = IERC20(usdc_);
        hot = hot_;
        harvestSink = harvestSink_;
    }

    function setOperator(address op, bool on) external onlyOwner {
        operator[op] = on;
        emit OperatorSet(op, on);
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setAttest(address a) external onlyOwner {
        attest = a;
    }

    function setRequireBorders(bool on) external onlyOwner {
        requireBorders = on;
    }

    function setCurators(address g, address s, address p) external onlyOwner {
        if (g != address(0) && IERC4626C(g).asset() != address(usdc)) revert NotUsdcVault();
        if (s != address(0) && IERC4626C(s).asset() != address(usdc)) revert NotUsdcVault();
        gauntlet = g;
        steakhouse = s;
        pendleSleeve = p;
        emit CuratorsSet(g, s, p);
    }

    function setWeights(uint16 g, uint16 s, uint16 p) external onlyOwner {
        if (uint256(g) + s + p != BPS) revert Bad();
        // Pendle sleeve ≤ 15% hard ceiling (~$30M of $200M)
        if (p > 1500) revert Bad();
        gauntletBps = g;
        steakBps = s;
        pendleBps = p;
        emit WeightsSet(g, s, p);
    }

    /// @notice Deploy up to remaining CAP. Pulls USDC from msg.sender (Hot/Landing/fill desk).
    /// @dev Reverts if USDC war-chest path empty — will not touch eUSD or gold.
    function deploy(uint256 usdcAmt) external onlyOp nonReentrant returns (uint256 deployed) {
        if (!armed) revert Disarmed();
        if (usdcAmt == 0) revert Bad();
        _gate();
        if (totalDeployed + usdcAmt > CAP) revert Cap();

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);

        uint256 toG = (usdcAmt * gauntletBps) / BPS;
        uint256 toS = (usdcAmt * steakBps) / BPS;
        uint256 toP = usdcAmt - toG - toS; // dust to sleeve

        if (toG > 0) {
            if (gauntlet == address(0)) revert Bad();
            usdc.safeApprove(gauntlet, toG);
            IERC4626C(gauntlet).deposit(toG, address(this));
        }
        if (toS > 0) {
            if (steakhouse == address(0)) revert Bad();
            usdc.safeApprove(steakhouse, toS);
            IERC4626C(steakhouse).deposit(toS, address(this));
        }
        if (toP > 0) {
            if (pendleSleeve == address(0)) {
                // No sleeve configured: park residual USDC on contract for later PT buy
            } else {
                usdc.safeApprove(pendleSleeve, toP);
                IERC4626C(pendleSleeve).deposit(toP, address(this));
            }
        }

        totalDeployed += usdcAmt;
        deployed = usdcAmt;
        emit Deployed(usdcAmt, toG, toS, toP);
    }

    /// @notice Redeem curator shares (amount in vault shares) and send USDC to harvestSink (Scroll path).
    function harvestGauntlet(uint256 shares) external onlyOp nonReentrant returns (uint256 assets) {
        _gate();
        assets = IERC4626C(gauntlet).redeem(shares, harvestSink, address(this));
        _shrinkPrincipal(assets);
        emit Harvested(assets, harvestSink);
    }

    function harvestSteak(uint256 shares) external onlyOp nonReentrant returns (uint256 assets) {
        _gate();
        assets = IERC4626C(steakhouse).redeem(shares, harvestSink, address(this));
        _shrinkPrincipal(assets);
        emit Harvested(assets, harvestSink);
    }

    /// @notice Sweep idle USDC (undeployed sleeve dust or residual) to harvest sink.
    function sweepUsdc(uint256 amt) external onlyOp nonReentrant {
        uint256 bal = usdc.balanceOf(address(this));
        uint256 send = amt == 0 || amt > bal ? bal : amt;
        if (send == 0) revert Bad();
        usdc.safeTransfer(harvestSink, send);
        emit Harvested(send, harvestSink);
    }

    function deployedValue() public view returns (uint256) {
        uint256 v;
        if (gauntlet != address(0)) {
            v += IERC4626C(gauntlet).convertToAssets(IERC4626C(gauntlet).balanceOf(address(this)));
        }
        if (steakhouse != address(0)) {
            v += IERC4626C(steakhouse).convertToAssets(IERC4626C(steakhouse).balanceOf(address(this)));
        }
        if (pendleSleeve != address(0)) {
            v += IERC4626C(pendleSleeve).convertToAssets(IERC4626C(pendleSleeve).balanceOf(address(this)));
        }
        v += usdc.balanceOf(address(this));
        return v;
    }

    function remainingCap() external view returns (uint256) {
        return CAP - totalDeployed;
    }

    function _shrinkPrincipal(uint256 assets) internal {
        if (assets >= totalDeployed) totalDeployed = 0;
        else totalDeployed -= assets;
    }

    function _gate() internal view {
        if (requireBorders && attest != address(0) && !IBordersC(attest).bordersSecure()) revert Borders();
    }
}
