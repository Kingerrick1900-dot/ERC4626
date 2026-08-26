// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownBorrowCapacity} from "../fleet/CrownBorrowCapacity.sol";

interface IMorphoFx {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function accrueInterest(MarketParams memory) external;
}

interface IEusdBurnFx {
    function transferFrom(address, address, uint256) external returns (bool);
    function burn(address from, uint256 amt) external;
    function balanceOf(address) external view returns (uint256);
    function isMinter(address) external view returns (bool);
}

/// @title CrownFxEngine
/// @notice Capacity-backed redeem fill: flashLoan USDC → pay receiver → same-tx borrow vs RSS → repay flash.
/// @dev Requires Morpho market idle ≥ ask (borrow leg). `armed=false` by default — no loans until King arms.
contract CrownFxEngine is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoFx public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoFx.MarketParams public mp;

    bool public armed; // King must flip true before any flash/borrow fill
    address public filler; // 8020 / authorized redeem caller
    uint256 public lastFillUsdc;
    uint256 public totalFilledUsdc;

    event Armed(bool on);
    event FillerSet(address indexed filler);
    event Filled(address indexed receiver, uint256 eusdIn, uint256 usdcOut, uint256 idleAfter);

    error NotArmed();
    error OnlyFiller();
    error BadAmt();
    error CapacityMiss();
    error IdleMiss();
    error MorphoOnly();
    error RepayMiss();

    modifier onlyFiller() {
        if (msg.sender != filler && msg.sender != owner && msg.sender != king) revert OnlyFiller();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address eusd_,
        address king_,
        bytes32 marketId_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoFx(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        king = king_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoFx(morpho_).idToMarketParams(marketId_);
        require(loan == usdc_, "LOAN");
        mp = IMorphoFx.MarketParams(loan, coll, oracle, irm, lltv);
        // armed stays false — do not take loans until King arms
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setFiller(address f) external onlyOwner {
        filler = f;
        emit FillerSet(f);
    }

    function idleUsdc() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function borrowCapacity() public view returns (uint256) {
        return CrownBorrowCapacity.borrowCapacity(address(morpho), marketId, king);
    }

    /// @notice Preview whether a fill would pass gates (does not execute).
    function canFill(uint256 usdcAmt) public view returns (bool) {
        if (!armed || usdcAmt == 0) return false;
        if (borrowCapacity() < usdcAmt) return false;
        if (idleUsdc() < usdcAmt) return false;
        return true;
    }

    /// @notice Redeem fill: pull eUSD from `from`, flash-pay `to` USDC, borrow vs King RSS, repay flash.
    /// @dev Reverts if !armed. King Morpho must authorize this engine before arming.
    function fillRedeem(uint256 eusdAmt, address from, address to)
        external
        onlyFiller
        nonReentrant
        returns (uint256 usdcOut)
    {
        if (!armed) revert NotArmed();
        if (eusdAmt == 0) revert BadAmt();
        if (to == address(0)) to = from;
        usdcOut = eusdAmt / 1e12; // 18dp → 6dp 1:1
        if (usdcOut == 0) revert BadAmt();
        if (borrowCapacity() < usdcOut) revert CapacityMiss();
        if (idleUsdc() < usdcOut) revert IdleMiss();

        eusd.safeTransferFrom(from, address(this), eusdAmt);
        // Hold eUSD on engine (burn path optional if minter); accounting sink for now
        morpho.flashLoan(address(usdc), usdcOut, abi.encode(to, usdcOut));

        lastFillUsdc = usdcOut;
        totalFilledUsdc += usdcOut;
        emit Filled(to, eusdAmt, usdcOut, idleUsdc());
    }

    /// @notice Morpho flash callback — pay receiver, borrow vs king, approve repay.
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert MorphoOnly();
        (address to, uint256 usdcAmt) = abi.decode(data, (address, uint256));
        require(assets == usdcAmt, "AMT");

        // 1) Pay redeem receiver
        usdc.safeTransfer(to, usdcAmt);

        // 2) Same-tx borrow vs King RSS collateral (engine must be authorized on Morpho)
        morpho.accrueInterest(mp);
        if (idleUsdc() < usdcAmt) revert IdleMiss();
        morpho.borrow(mp, usdcAmt, 0, king, address(this));

        // 3) Repay flash
        if (usdc.balanceOf(address(this)) < usdcAmt) revert RepayMiss();
        usdc.approve(address(morpho), usdcAmt);
    }
}
