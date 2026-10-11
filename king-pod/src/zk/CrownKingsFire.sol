// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownGateV2} from "../CrownGateV2.sol";
import {CrownZkCredit} from "./CrownZkCredit.sol";

interface IZkKings {
    function isProven(address subject) external view returns (bool);
}

interface IMorphoKings {
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

/// @title CrownKingsFire — King Fire Order (ZK mandatory)
/// @notice Opens BORROW_USDC + CROWN_CREDIT against live CrownGateV2 RSS @ $50k.
/// @dev Modes:
///      fireMatched() — flash seed → draw to this → repay flash (debt live; Morpho-named repay).
///      fireWithCover() — King USDC cover in-callback → draws to Landing → repay from cover.
contract CrownKingsFire is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    uint256 public constant BORROW_USDC = 1_000_000e6;
    uint256 public constant CROWN_CREDIT = 100_000e6;
    uint256 public constant FLASH_AMT = 1_100_000e6;

    IMorphoKings public immutable morpho;
    IERC20 public immutable usdc;
    IZkKings public immutable zkGate;
    CrownGateV2 public immutable morphoGate;
    CrownZkCredit public immutable credit;
    address public immutable king;
    address public immutable landing;

    uint8 private _mode; // 1=matched 2=cover

    event KingsFireMatched(uint256 borrowUsdc, uint256 crownCredit);
    event KingsFireCovered(uint256 borrowUsdc, uint256 crownCredit, address indexed landing);

    error KingOnly();
    error NotProven();
    error OnlyMorpho();
    error CoverMiss();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address zkGate_,
        address morphoGate_,
        address credit_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoKings(morpho_);
        usdc = IERC20(usdc_);
        zkGate = IZkKings(zkGate_);
        morphoGate = CrownGateV2(morphoGate_);
        credit = CrownZkCredit(credit_);
        king = king_;
        landing = landing_;
    }

    /// @notice FIRE matched books: 1M Morpho debt + 100k Credit debt. ZK. Flash repay = draws to this.
    function fireMatched() external onlyKing nonReentrant {
        if (!zkGate.isProven(king)) revert NotProven();
        _mode = 1;
        morpho.flashLoan(address(usdc), FLASH_AMT, "");
        _mode = 0;
        emit KingsFireMatched(BORROW_USDC, CROWN_CREDIT);
    }

    /// @notice FIRE with King USDC cover: draws land on `landing`. Requires allowance ≥ FLASH_AMT.
    function fireWithCover() external onlyKing nonReentrant {
        if (!zkGate.isProven(king)) revert NotProven();
        if (usdc.balanceOf(king) < FLASH_AMT) revert CoverMiss();
        _mode = 2;
        morpho.flashLoan(address(usdc), FLASH_AMT, "");
        _mode = 0;
        emit KingsFireCovered(BORROW_USDC, CROWN_CREDIT, landing);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != address(morpho) || _mode == 0) revert OnlyMorpho();
        if (assets != FLASH_AMT) revert CoverMiss();

        usdc.safeApprove(address(morpho), type(uint256).max);
        usdc.safeApprove(address(credit), CROWN_CREDIT);

        (address a, address b, address c, address d, uint256 e) = morpho.idToMarketParams(SOV);
        IMorphoKings.MarketParams memory sovMp =
            IMorphoKings.MarketParams({loanToken: a, collateralToken: b, oracle: c, irm: d, lltv: e});

        morpho.supply(sovMp, BORROW_USDC, 0, address(this), "");
        credit.supply(CROWN_CREDIT);

        if (_mode == 1) {
            morphoGate.borrowUSDC(BORROW_USDC, address(this));
            credit.operatorBorrowTo(address(this), CROWN_CREDIT);
        } else {
            usdc.safeTransferFrom(king, address(this), FLASH_AMT);
            morphoGate.borrowUSDC(BORROW_USDC, landing);
            credit.operatorBorrowTo(landing, CROWN_CREDIT);
        }

        if (usdc.balanceOf(address(this)) < assets) revert CoverMiss();
        usdc.safeApprove(address(morpho), assets);
    }
}
