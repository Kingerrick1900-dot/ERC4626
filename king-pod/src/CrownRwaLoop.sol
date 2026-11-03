// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMetaMorphoRwa {
    function asset() external view returns (address);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

interface IMorphoRwa {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supplyCollateral(MarketParams memory m, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory m, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function createMarket(MarketParams memory marketParams) external;
    function isAuthorized(address user, address operator) external view returns (bool);
}

interface IOracleRwa {
    function price() external view returns (uint256);
}

interface IRwaSwapper {
    /// @notice USDC → RWA (e.g. USDY). Returns RWA amount received (18dp typical).
    function usdcToRwa(uint256 usdcIn, uint256 minRwaOut) external returns (uint256 rwaOut);
    /// @notice RWA → USDC. Returns USDC amount received (6dp).
    function rwaToUsdc(uint256 rwaIn, uint256 minUsdcOut) external returns (uint256 usdcOut);
}

interface IColdBufferRwa {
    function receiveYield(uint256 amt, bytes32 tag) external;
}

interface IZkGateRwa {
    function isProven(address subject) external view returns (bool);
}

/// @notice RWA loop: yRSS USDC → USDY collateral → Morpho borrow @ ≤85% → recycle. Spread → ColdBuffer.
/// @dev Pilot-capped. No fake TVL. Requires free maxWithdraw (or seed) + live Morpho RWA market + swapper.
///      Flash path = atomic leverage with named Morpho repay (flash fee 0).
contract CrownRwaLoop is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant TAG_RWA = bytes32("RWA_LOOP");
    bytes32 public constant TAG_FLASH = bytes32("FLASH_LEV");

    IERC20 public immutable usdc;
    IERC20 public immutable rwa; // USDY
    IMetaMorphoRwa public immutable yrss;
    IMorphoRwa public immutable morpho;
    address public immutable king;

    IMorphoRwa.MarketParams public market;
    bytes32 public marketId;
    IRwaSwapper public swapper;
    IColdBufferRwa public coldBuffer;
    IZkGateRwa public gate;

    uint256 public pilotCap; // USDC 6dp — package default 10M
    uint256 public targetLtvBps; // e.g. 8500 = 85% of oracle value
    uint256 public maxLoops; // recursion depth cap
    uint256 public totalPulled;
    uint256 public totalRwaHeld;
    uint256 public totalBorrowed;
    uint256 public totalYieldPushed;
    bool public armed;

    bool private _flashing;

    event Armed(bool ok);
    event PilotCap(uint256 cap);
    event MarketSet(bytes32 marketId, address oracle, uint256 lltv);
    event SwapperSet(address swapper);
    event ColdBufferSet(address buffer);
    event GateSet(address gate);
    event LtvBps(uint256 bps);
    event Pulled(uint256 usdcAmt);
    event Looped(uint256 rwaIn, uint256 borrowed, uint256 iter);
    event FlashLooped(uint256 flashUsdc, uint256 rwaOut, uint256 debt);
    event YieldPushed(uint256 amt, bytes32 tag);

    error Bad();
    error NotArmed();
    error Cap();
    error NoLiquidity();
    error NotProven();
    error OnlyMorpho();
    error NotAuth();
    error Slip();

    constructor(
        address usdc_,
        address rwa_,
        address yrss_,
        address morpho_,
        address king_,
        address owner_,
        uint256 pilotCap_
    ) Ownable(owner_) {
        if (
            usdc_ == address(0) || rwa_ == address(0) || yrss_ == address(0) || morpho_ == address(0)
                || king_ == address(0) || pilotCap_ == 0
        ) revert Bad();
        usdc = IERC20(usdc_);
        rwa = IERC20(rwa_);
        yrss = IMetaMorphoRwa(yrss_);
        morpho = IMorphoRwa(morpho_);
        king = king_;
        pilotCap = pilotCap_;
        targetLtvBps = 8500;
        maxLoops = 12;
    }

    function setArmed(bool ok) external onlyOwner {
        armed = ok;
        emit Armed(ok);
    }

    function setPilotCap(uint256 cap) external onlyOwner {
        if (cap == 0 || cap > 35_000_000e6) revert Bad(); // hard ceiling: actual 35M yRSS bag — no fake 90M
        pilotCap = cap;
        emit PilotCap(cap);
    }

    function setTargetLtvBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps > 8500) revert Bad(); // never above package 85%
        targetLtvBps = bps;
        emit LtvBps(bps);
    }

    function setMaxLoops(uint256 n) external onlyOwner {
        if (n == 0 || n > 32) revert Bad();
        maxLoops = n;
    }

    function setMarket(IMorphoRwa.MarketParams calldata m, bytes32 id) external onlyOwner {
        if (m.loanToken != address(usdc) || m.collateralToken != address(rwa)) revert Bad();
        if (m.lltv > 0.85e18) revert Bad();
        market = m;
        marketId = id;
        emit MarketSet(id, m.oracle, m.lltv);
    }

    function setSwapper(address s) external onlyOwner {
        if (s == address(0)) revert Bad();
        swapper = IRwaSwapper(s);
        emit SwapperSet(s);
    }

    function setColdBuffer(address b) external onlyOwner {
        if (b == address(0)) revert Bad();
        coldBuffer = IColdBufferRwa(b);
        emit ColdBufferSet(b);
    }

    function setGate(address g) external onlyOwner {
        gate = IZkGateRwa(g);
        emit GateSet(g);
    }

    function _requireFire() internal view {
        if (!armed) revert NotArmed();
        if (address(gate) != address(0) && !gate.isProven(king)) revert NotProven();
        if (!morpho.isAuthorized(king, address(this))) revert NotAuth();
        if (address(swapper) == address(0) || marketId == bytes32(0)) revert Bad();
    }

    /// @notice Pull free USDC from king's yRSS into this loop (pilot-capped).
    /// @dev King must `yrss.approve(loop, shares)` first. Reverts if maxWithdraw < ask (matched book).
    function pullFromYrss(uint256 ask) external onlyOwner nonReentrant returns (uint256 got) {
        _requireFire();
        if (ask == 0) revert Bad();
        if (totalPulled + ask > pilotCap) revert Cap();
        if (yrss.maxWithdraw(king) < ask) revert NoLiquidity();
        uint256 before = usdc.balanceOf(address(this));
        yrss.withdraw(ask, address(this), king);
        got = usdc.balanceOf(address(this)) - before;
        if (got < ask) revert NoLiquidity();
        totalPulled += got;
        emit Pulled(got);
    }

    /// @notice Seed loop with free USDC (Landing/HOT) — bypasses yRSS when maxWithdraw dust.
    function seedUsdc(uint256 amt) external onlyOwner nonReentrant {
        _requireFire();
        if (amt == 0) revert Bad();
        if (totalPulled + amt > pilotCap) revert Cap();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        totalPulled += amt;
        emit Pulled(amt);
    }

    /// @notice Recursive RWA loop on idle USDC held by this contract.
    function loopIdle(uint256 minRwaOutBps) external onlyOwner nonReentrant {
        _requireFire();
        uint256 usdcBal = usdc.balanceOf(address(this));
        if (usdcBal == 0) revert NoLiquidity();

        for (uint256 i; i < maxLoops; ++i) {
            usdcBal = usdc.balanceOf(address(this));
            if (usdcBal < 1e6) break; // < $1 dust

            usdc.safeApprove(address(swapper), 0);
            usdc.safeApprove(address(swapper), usdcBal);
            uint256 minOut = (usdcBal * 1e12 * minRwaOutBps) / 10_000; // USDC6→18 scale * bps
            uint256 rwaOut = swapper.usdcToRwa(usdcBal, minOut);
            if (rwaOut == 0) revert Slip();

            rwa.safeApprove(address(morpho), 0);
            rwa.safeApprove(address(morpho), rwaOut);
            morpho.supplyCollateral(market, rwaOut, king, "");
            totalRwaHeld += rwaOut;

            uint256 borrowAmt = _borrowCapacity(rwaOut);
            if (borrowAmt < 1e6) {
                emit Looped(rwaOut, 0, i);
                break;
            }
            morpho.borrow(market, borrowAmt, 0, king, address(this));
            totalBorrowed += borrowAmt;
            emit Looped(rwaOut, borrowAmt, i);
        }
    }

    /// @notice Atomic flash leverage: equity on contract + flash → buy RWA → coll → borrow flash → repay.
    /// @dev At 85% LTV, equity must cover ≥15% of purchase (flash alone cannot repay 1:1). Named Morpho repay.
    function flashLeverage(uint256 flashUsdc, uint256 minRwaOutBps) external onlyOwner nonReentrant {
        _requireFire();
        if (flashUsdc == 0) revert Bad();
        uint256 equity = usdc.balanceOf(address(this));
        if (equity == 0) revert NoLiquidity();
        if (totalPulled + equity > pilotCap) revert Cap();
        _flashing = true;
        morpho.flashLoan(address(usdc), flashUsdc, abi.encode(flashUsdc, minRwaOutBps));
        _flashing = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_flashing) revert Bad();
        (uint256 flashUsdc, uint256 minRwaOutBps) = abi.decode(data, (uint256, uint256));
        if (assets != flashUsdc) revert Bad();

        // Spend equity + flash on RWA
        uint256 buy = usdc.balanceOf(address(this));
        usdc.safeApprove(address(swapper), 0);
        usdc.safeApprove(address(swapper), buy);
        uint256 minOut = (buy * 1e12 * minRwaOutBps) / 10_000;
        uint256 rwaOut = swapper.usdcToRwa(buy, minOut);
        if (rwaOut == 0) revert Slip();

        rwa.safeApprove(address(morpho), 0);
        rwa.safeApprove(address(morpho), rwaOut);
        morpho.supplyCollateral(market, rwaOut, king, "");
        totalRwaHeld += rwaOut;

        // Borrow only the flash size to repay (capacity must cover flash)
        uint256 cap = _borrowCapacity(rwaOut);
        if (cap < assets) revert Cap();
        morpho.borrow(market, assets, 0, king, address(this));
        totalBorrowed += assets;

        usdc.safeApprove(address(morpho), 0);
        usdc.safeApprove(address(morpho), assets);
        emit FlashLooped(assets, rwaOut, assets);
    }

    /// @notice Skim free USDC on this contract to ColdBuffer (harvest / leftover).
    function pushYield(uint256 amt) external onlyOwner nonReentrant {
        if (address(coldBuffer) == address(0)) revert Bad();
        if (amt == 0) amt = usdc.balanceOf(address(this));
        if (amt == 0) revert NoLiquidity();
        usdc.safeApprove(address(coldBuffer), 0);
        usdc.safeApprove(address(coldBuffer), amt);
        coldBuffer.receiveYield(amt, TAG_RWA);
        totalYieldPushed += amt;
        emit YieldPushed(amt, TAG_RWA);
    }

    function _borrowCapacity(uint256 rwaAmt) internal view returns (uint256) {
        // Morpho oracle: loan-units per 1 coll-wei, scaled 1e36
        uint256 px = IOracleRwa(market.oracle).price();
        // value in USDC raw (6dp) ≈ rwaAmt * px / 1e36
        uint256 valueUsdc = (rwaAmt * px) / 1e36;
        return (valueUsdc * targetLtvBps) / 10_000;
    }

    function pilotRemaining() external view returns (uint256) {
        return pilotCap > totalPulled ? pilotCap - totalPulled : 0;
    }
}
