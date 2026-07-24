// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {IZkGateBook, ZkKingGate} from "./lib/ZkKingGate.sol";

interface IMorphoLiq {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function accrueInterest(MarketParams memory) external;

    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Pre-armed Morpho self-liq with ZK packing — Morpho flash path, not a ZK loan.
contract CrownElepanPreSelfLiq is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;
    using ZkKingGate for IZkGateBook;

    IZkGateBook public immutable gate;
    IMorphoLiq public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable elepan;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoLiq.MarketParams public mp;
    address public operator;

    bool private _locking;

    event SelfLiq(uint256 debtClosedShares, uint256 eleToLanding, uint256 usdcToLanding, uint256 supplyWithdrawn);
    event PassiveSkim(uint256 usdcToLanding);
    event OperatorSet(address indexed operator);

    error OnlyMorpho();
    error Auth();
    error Short();
    error NoDebt();

    modifier onlyOwnerOrOperator() {
        require(msg.sender == owner || msg.sender == operator, "OWN");
        _;
    }

    constructor(
        address gate_,
        address morpho_,
        address usdc_,
        address elepan_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        gate = IZkGateBook(gate_);
        morpho = IMorphoLiq(morpho_);
        usdc = IERC20(usdc_);
        elepan = IERC20(elepan_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoLiq.MarketParams({
            loanToken: usdc_,
            collateralToken: elepan_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    function setOperator(address op) external onlyOwner {
        operator = op;
        emit OperatorSet(op);
    }

    function fundBuffer(uint256 assets) external onlyOwnerOrOperator {
        gate.requireProven(king);
        usdc.safeTransferFrom(msg.sender, address(this), assets);
    }

    function skimPassive() external onlyOwnerOrOperator nonReentrant {
        gate.requireProven(king);
        uint256 bal = usdc.balanceOf(address(this));
        require(bal > 0, "ZERO");
        usdc.safeTransfer(landing, bal);
        emit PassiveSkim(bal);
    }

    function selfLiquidate() external onlyOwnerOrOperator nonReentrant {
        gate.requireProven(king);
        if (!morpho.isAuthorized(king, address(this))) revert Auth();

        morpho.accrueInterest(mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        if (borShares == 0) revert NoDebt();

        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
        flashAmt += 1e6;

        uint256 eleBefore = elepan.balanceOf(landing);
        uint256 usdcBefore = usdc.balanceOf(landing);

        _locking = true;
        morpho.flashLoan(address(usdc), flashAmt, abi.encode(supShares, uint256(borShares), uint256(coll)));
        _locking = false;

        uint256 eleHere = elepan.balanceOf(address(this));
        if (eleHere > 0) elepan.safeTransfer(landing, eleHere);
        uint256 usdcHere = usdc.balanceOf(address(this));
        if (usdcHere > 0) usdc.safeTransfer(landing, usdcHere);

        emit SelfLiq(
            borShares,
            elepan.balanceOf(landing) - eleBefore,
            usdc.balanceOf(landing) - usdcBefore,
            supShares
        );
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        (uint256 supShares, uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256, uint256));

        usdc.safeApprove(address(morpho), 0);
        usdc.safeApprove(address(morpho), type(uint256).max);

        if (borShares > 0) morpho.repay(mp, 0, borShares, king, "");
        if (coll > 0) morpho.withdrawCollateral(mp, coll, king, landing);
        if (supShares > 0) morpho.withdraw(mp, 0, supShares, king, address(this));

        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.safeApprove(address(morpho), assets);
    }
}
