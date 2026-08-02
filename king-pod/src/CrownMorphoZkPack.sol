// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {IZkGateBook, ZkKingGate} from "./lib/ZkKingGate.sol";

interface IMorphoHub {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IOracleHub {
    function price() external view returns (uint256);
}

interface IZkCreditHub {
    function maxBorrow(address) external view returns (uint256);
    function lltv() external view returns (uint256);
    function landing() external view returns (address);
    function king() external view returns (address);
}

interface IKeepDrawHub {
    function borrowPortion(uint256 assets) external returns (uint256);
    function drawKeep(uint256 supplyUsdc, uint256 postEle, uint256 borrowUsdc) external;
}

interface ISelfLiqHub {
    function selfLiquidate() external;
    function skimPassive() external;
}

/// @notice Morpho ELE/USDC loan hub with ZK packing (attest gate) — not a ZK loan.
/// @dev Loan = Morpho Blue borrow(). Pack = gate.isProven + attest for counterparties.
///      Morpho coll stays on-chain. ZK does not replace Morpho liquidity.
contract CrownMorphoZkPack is Ownable, ReentrancyGuard {
    using ZkKingGate for IZkGateBook;

    IZkGateBook public immutable gate;
    IZkCreditHub public immutable credit;
    IMorphoHub public immutable morpho;
    IERC20 public immutable usdc;
    address public immutable king;
    address public immutable landing;
    address public immutable elepan;
    address public immutable oracle;
    bytes32 public immutable marketId;
    uint256 public immutable morphoLltv;

    IKeepDrawHub public keepDraw;
    ISelfLiqHub public preSelfLiq;

    event Wired(address keepDraw, address preSelfLiq);
    event ZkPortion(uint256 assets, uint256 landingBal);

    constructor(
        address gate_,
        address credit_,
        address morpho_,
        address usdc_,
        address elepan_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        uint256 morphoLltv_,
        address owner_
    ) Ownable(owner_) {
        gate = IZkGateBook(gate_);
        credit = IZkCreditHub(credit_);
        morpho = IMorphoHub(morpho_);
        usdc = IERC20(usdc_);
        elepan = elepan_;
        king = king_;
        landing = landing_;
        marketId = marketId_;
        oracle = oracle_;
        morphoLltv = morphoLltv_;
        require(credit.king() == king_ && credit.landing() == landing_, "CREDIT_CFG");
    }

    /// @dev Caller must separately `keepDraw.setOperator(book)` and `preSelfLiq.setOperator(book)`.
    function wire(address keepDraw_, address preSelfLiq_) external onlyOwner {
        keepDraw = IKeepDrawHub(keepDraw_);
        preSelfLiq = ISelfLiqHub(preSelfLiq_);
        emit Wired(keepDraw_, preSelfLiq_);
    }

    function book()
        external
        view
        returns (
            bool proven,
            uint256 attestUsdc6,
            uint256 minThreshold,
            uint256 zkMaxBorrow,
            uint256 morphoIdle,
            uint256 morphoRoom,
            uint256 morphoDebt,
            uint256 morphoColl,
            uint256 landingUsdc
        )
    {
        proven = gate.isProven(king);
        attestUsdc6 = gate.attestValue(king);
        minThreshold = gate.minThreshold();
        zkMaxBorrow = credit.maxBorrow(king);

        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        morphoIdle = uint256(s) - uint256(b);

        (, uint128 bor, uint128 coll) = morpho.position(marketId, king);
        morphoColl = uint256(coll);
        if (bor > 0 && b > 0) {
            (,, uint128 ba, uint128 bs,,) = morpho.market(marketId);
            morphoDebt = (uint256(ba) * uint256(bor) + uint256(bs) - 1) / uint256(bs);
        }
        uint256 price = IOracleHub(oracle).price();
        uint256 collValue = (morphoColl * price) / 1e36;
        uint256 maxByLltv = (collValue * morphoLltv) / 1e18;
        morphoRoom = maxByLltv > morphoDebt ? maxByLltv - morphoDebt : 0;
        landingUsdc = usdc.balanceOf(landing);
    }

    function borrowPortionZk(uint256 assets) external onlyOwner nonReentrant returns (uint256 borrowed) {
        gate.requireProven(king);
        require(address(keepDraw) != address(0), "NO_KEEP");
        borrowed = keepDraw.borrowPortion(assets);
        emit ZkPortion(borrowed, usdc.balanceOf(landing));
    }

    function drawKeepZk(uint256 supplyUsdc, uint256 postEle, uint256 borrowUsdc) external onlyOwner nonReentrant {
        gate.requireProven(king);
        require(address(keepDraw) != address(0), "NO_KEEP");
        keepDraw.drawKeep(supplyUsdc, postEle, borrowUsdc);
    }

    function selfLiquidateZk() external onlyOwner nonReentrant {
        gate.requireProven(king);
        require(address(preSelfLiq) != address(0), "NO_LIQ");
        preSelfLiq.selfLiquidate();
    }

    function skimPassiveZk() external onlyOwner nonReentrant {
        gate.requireProven(king);
        require(address(preSelfLiq) != address(0), "NO_LIQ");
        preSelfLiq.skimPassive();
    }
}
