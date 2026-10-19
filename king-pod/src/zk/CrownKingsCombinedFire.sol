// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownGateV2} from "../CrownGateV2.sol";
import {CrownZkYieldLadder} from "../CrownZkYieldLadder.sol";

interface IZkComb {
    function isProven(address subject) external view returns (bool);
}

interface IMorphoComb {
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
    function idToMarketParams(bytes32 id) external view returns (address, address, address, address, uint256);
}

/// @title CrownKingsCombinedFire — Borrow #2 Engine + Borrow #1 Reserve · ZK mandatory
contract CrownKingsCombinedFire is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    uint256 public constant ENGINE_USDC = 1_000_000e6;
    uint256 public constant RESERVE_USDC = 1_000_000e6;
    uint256 public constant FLASH_AMT = 2_000_000e6;

    IMorphoComb public immutable morpho;
    IERC20 public immutable usdc;
    IZkComb public immutable zkGate;
    CrownGateV2 public immutable morphoGate;
    address public immutable king;
    address public immutable landing;

    CrownZkYieldLadder public ladder;
    uint8 private _mode; // 1=matched 2=cover

    event CombinedMatched(uint256 engineLp, uint256 reserveDebt);
    event CombinedCovered(uint256 engineToLadder, uint256 reserveToHot);

    error KingOnly();
    error NotProven();
    error OnlyMorpho();
    error CoverMiss();
    error LadderUnset();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address zkGate_,
        address morphoGate_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoComb(morpho_);
        usdc = IERC20(usdc_);
        zkGate = IZkComb(zkGate_);
        morphoGate = CrownGateV2(morphoGate_);
        king = king_;
        landing = landing_;
    }

    function setLadder(address ladder_) external onlyOwner {
        ladder = CrownZkYieldLadder(ladder_);
    }

    /// @notice +$2M gate debt, $2M Morpho LP on this (engine yield book). Flash repay = borrow.
    function fireMatched() external onlyKing nonReentrant {
        if (!zkGate.isProven(king)) revert NotProven();
        _mode = 1;
        morpho.flashLoan(address(usdc), FLASH_AMT, "");
        _mode = 0;
        emit CombinedMatched(ENGINE_USDC, RESERVE_USDC);
    }

    /// @notice King cover ≥ $2M: seed ladder $1M (engine) + $1M to HOT (reserve) + $2M gate debt.
    function fireWithCover() external onlyKing nonReentrant {
        if (!zkGate.isProven(king)) revert NotProven();
        if (address(ladder) == address(0)) revert LadderUnset();
        if (usdc.balanceOf(king) < FLASH_AMT) revert CoverMiss();
        _mode = 2;
        morpho.flashLoan(address(usdc), FLASH_AMT, "");
        _mode = 0;
        emit CombinedCovered(ENGINE_USDC, RESERVE_USDC);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != address(morpho) || _mode == 0) revert OnlyMorpho();
        if (assets != FLASH_AMT) revert CoverMiss();

        usdc.safeApprove(address(morpho), type(uint256).max);
        (address a, address b, address c, address d, uint256 e) = morpho.idToMarketParams(SOV);
        IMorphoComb.MarketParams memory sovMp =
            IMorphoComb.MarketParams({loanToken: a, collateralToken: b, oracle: c, irm: d, lltv: e});

        if (_mode == 1) {
            // Engine book = Morpho LP on this (yield accrues). Reserve debt opens on gate.
            morpho.supply(sovMp, FLASH_AMT, 0, address(this), "");
            morphoGate.borrowUSDC(FLASH_AMT, address(this));
        } else {
            // cover + flash = 4M working · Engine → ladder idle · Reserve → HOT
            usdc.safeTransferFrom(king, address(this), FLASH_AMT);
            morpho.supply(sovMp, FLASH_AMT, 0, address(this), "");
            usdc.safeTransfer(address(ladder), ENGINE_USDC);
            usdc.safeTransfer(landing, RESERVE_USDC);
            morphoGate.borrowUSDC(FLASH_AMT, address(this));
        }

        if (usdc.balanceOf(address(this)) < assets) revert CoverMiss();
        usdc.safeApprove(address(morpho), assets);
    }
}
