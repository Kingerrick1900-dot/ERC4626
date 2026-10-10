// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownGateV2} from "../CrownGateV2.sol";

interface IZkIdleGate {
    function isProven(address subject) external view returns (bool);
}

interface IMorphoIdle {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32 id) external view returns (address, address, address, address, uint256);
}

interface IMetaMorphoIdle {
    function maxWithdraw(address owner) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @title CrownZkIdleEngineer — put the King in Morpho IDLE
/// @notice Flash 2×amt → supply IDLE + SOV onBehalf yRSS → CrownGateV2 borrow amt → repay flash.
/// @dev Doctrine: ZK mandatory. Fine print: Morpho flash + supply(onBehalf:yRSS) — no King USDC prefund.
///      End: yRSS holds IDLE inventory (King in the pool) + SOV liquidity; gate carries amt debt; flash flat.
contract CrownZkIdleEngineer is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant IDLE = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;
    bytes32 public constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    IMorphoIdle public immutable morpho;
    IERC20 public immutable usdc;
    IMetaMorphoIdle public immutable yrss;
    IZkIdleGate public immutable zkGate;
    address public immutable king;
    CrownGateV2 public immutable morphoGate;

    bool private _inFlash;
    uint256 private _amt;

    uint256 public lastIdleShares;
    uint256 public lastSovShares;
    uint256 public lastMaxWithdraw;
    uint256 public lastTotalAssets;

    event IdleSovMatched(
        uint256 idleAmt, uint256 sovAmt, uint256 gateBorrow, uint256 idleShares, uint256 maxWithdraw, uint256 totalAssets
    );

    error KingOnly();
    error NotProven();
    error BadAmt();
    error OnlyMorpho();
    error IdleMiss();
    error SovMiss();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address yrss_,
        address zkGate_,
        address morphoGate_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoIdle(morpho_);
        usdc = IERC20(usdc_);
        yrss = IMetaMorphoIdle(yrss_);
        zkGate = IZkIdleGate(zkGate_);
        morphoGate = CrownGateV2(morphoGate_);
        king = king_;
    }

    /// @notice Engineer King into IDLE permanently (matched with SOV book for flash repay).
    /// @param amt USDC 6dp — idle credit to yRSS and SOV credit to yRSS; gate borrows `amt` to repay 2× flash.
    function engineerIdleSovMatch(uint256 amt) external onlyKing nonReentrant {
        if (amt == 0) revert BadAmt();
        if (!zkGate.isProven(king)) revert NotProven();
        _amt = amt;
        _inFlash = true;
        morpho.flashLoan(address(usdc), amt * 2, "");
        _inFlash = false;
        emit IdleSovMatched(amt, amt, amt, lastIdleShares, lastMaxWithdraw, lastTotalAssets);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != address(morpho) || !_inFlash) revert OnlyMorpho();
        uint256 amt = _amt;
        if (assets != amt * 2) revert BadAmt();

        usdc.safeApprove(address(morpho), assets);

        IMorphoIdle.MarketParams memory idleMp = _params(IDLE);
        IMorphoIdle.MarketParams memory sovMp = _params(SOV);

        // 1) King into IDLE pool — inventory on yRSS, no vault shares minted
        morpho.supply(idleMp, amt, 0, address(yrss), "");
        (lastIdleShares,,) = morpho.position(IDLE, address(yrss));
        if (lastIdleShares == 0) revert IdleMiss();

        // 2) Matching SOV liquidity so gate can borrow the repay slice
        morpho.supply(sovMp, amt, 0, address(yrss), "");
        (lastSovShares,,) = morpho.position(SOV, address(yrss));
        if (lastSovShares == 0) revert SovMiss();

        lastMaxWithdraw = yrss.maxWithdraw(king);
        lastTotalAssets = yrss.totalAssets();

        // 3) ZK-gated Morpho borrow against gate RSS @ $50k — repay source named: Morpho.borrow(SOV)
        morphoGate.borrowUSDC(amt, address(this));

        usdc.safeApprove(address(morpho), assets);
    }

    function _params(bytes32 id) internal view returns (IMorphoIdle.MarketParams memory mp) {
        (address a, address b, address c, address d, uint256 e) = morpho.idToMarketParams(id);
        mp = IMorphoIdle.MarketParams({loanToken: a, collateralToken: b, oracle: c, irm: d, lltv: e});
    }
}
