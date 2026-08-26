// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {IERC8020} from "./interfaces/IERC8020.sol";
import {CrownBorrowCapacity} from "../fleet/CrownBorrowCapacity.sol";

interface IPsmRedeem2 {
    function redeemUsdc(uint256 eusdAmt, address to) external returns (uint256 usdcOut);
    function usdcReserve() external view returns (uint256);
}

interface IFxEngine8020 {
    function canFill(uint256 usdcAmt) external view returns (bool);
    function fillRedeem(uint256 eusdAmt, address from, address to) external returns (uint256 usdcOut);
    function armed() external view returns (bool);
}

/// @title CrownSyncRedeem8020
/// @notice Sync redeem eUSD→USDC. maxRedeemSync = Morpho borrow capacity.
/// @dev Fill: PSM inventory first; else FxEngine (flash→pay→borrow→repay) when armed.
contract CrownSyncRedeem8020 is IERC8020, Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    address public immutable gusd;
    IPsmRedeem2 public immutable psm;
    IERC20 public immutable usdc;
    address public morpho;
    bytes32 public capacityMarketId;
    address public capacityUser;
    IFxEngine8020 public fxEngine;

    event SyncRedeemed(address indexed owner, address indexed receiver, uint256 eusdIn, uint256 usdcOut);
    event CapacityWired(address morpho, bytes32 marketId, address user);
    event FxEngineSet(address indexed engine);

    error BadAmt();
    error LiquidityMiss();

    constructor(address eusd_, address gusd_, address psm_, address usdc_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0) && psm_ != address(0) && usdc_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        gusd = gusd_;
        psm = IPsmRedeem2(psm_);
        usdc = IERC20(usdc_);
    }

    function wireCapacity(address morpho_, bytes32 marketId_, address user_) external onlyOwner {
        require(morpho_ != address(0) && user_ != address(0) && marketId_ != bytes32(0), "ZERO");
        morpho = morpho_;
        capacityMarketId = marketId_;
        capacityUser = user_;
        emit CapacityWired(morpho_, marketId_, user_);
    }

    function setFxEngine(address engine_) external onlyOwner {
        fxEngine = IFxEngine8020(engine_);
        emit FxEngineSet(engine_);
    }

    function borrowCapacityUsdc() public view returns (uint256) {
        if (morpho == address(0)) return 0;
        return CrownBorrowCapacity.borrowCapacity(morpho, capacityMarketId, capacityUser);
    }

    function maxRedeemSync(address) public view returns (uint256) {
        uint256 cap = borrowCapacityUsdc();
        if (cap == 0) return psm.usdcReserve() * 1e12;
        return cap * 1e12;
    }

    function previewRedeemSync(uint256 assets) public view returns (uint256) {
        if (assets == 0 || assets > maxRedeemSync(address(0))) return 0;
        return assets / 1e12;
    }

    function redeemSync(uint256 assets, address receiver, address owner_)
        external
        nonReentrant
        returns (uint256 usdcOut)
    {
        if (assets == 0) revert BadAmt();
        if (receiver == address(0)) receiver = msg.sender;
        if (owner_ == address(0)) owner_ = msg.sender;
        if (assets > maxRedeemSync(owner_)) revert LiquidityMiss();

        uint256 needUsdc = assets / 1e12;

        // Path A: PSM inventory
        if (psm.usdcReserve() >= needUsdc) {
            eusd.safeTransferFrom(owner_, address(this), assets);
            eusd.safeApprove(address(psm), 0);
            eusd.safeApprove(address(psm), assets);
            usdcOut = psm.redeemUsdc(assets, address(this));
            if (usdcOut == 0) revert LiquidityMiss();
            usdc.safeTransfer(receiver, usdcOut);
            emit SyncRedeemed(owner_, receiver, assets, usdcOut);
            return usdcOut;
        }

        // Path B: FxEngine capacity fill (must be armed — King controls loan fire)
        if (address(fxEngine) == address(0) || !fxEngine.canFill(needUsdc)) revert LiquidityMiss();
        eusd.safeTransferFrom(owner_, address(this), assets);
        eusd.safeApprove(address(fxEngine), assets);
        usdcOut = fxEngine.fillRedeem(assets, address(this), receiver);
        if (usdcOut == 0) revert LiquidityMiss();
        emit SyncRedeemed(owner_, receiver, assets, usdcOut);
    }
}
