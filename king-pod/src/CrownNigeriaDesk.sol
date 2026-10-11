// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateND {
    function isProven(address subject) external view returns (bool);
}

interface IBordersND {
    function bordersSecure() external view returns (bool);
}

interface IHotOracleND {
    function getPrice() external view returns (uint256);
}

/// @notice Build 5 — Nigeria remittance desk. One fire: settleRemittance.
/// @dev 200 bps (2%) fee → HOT/Safe in USDC. KYC off-chain. Wired to KRT + HotOracle50k.
contract CrownNigeriaDesk is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant FEE_BPS = 200; // 2%
    uint256 public constant BPS = 10_000;

    IERC20 public immutable usdc;
    IHotOracleND public immutable oracle;
    address public immutable krt;
    IZkGateND public immutable zkGate;
    IBordersND public immutable attest;
    address public immutable king;
    address public immutable feeSink; // HOT — real USDC fees

    uint256 public totalVolumeUsdc;
    uint256 public totalFeesUsdc;
    uint256 public settleCount;

    event RemittanceSettled(
        address indexed sender, address indexed agent, uint256 usdcIn, uint256 fee, uint256 net, uint256 oraclePrice
    );

    error Auth();
    error Zero();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(
        address usdc_,
        address oracle_,
        address krt_,
        address zkGate_,
        address attest_,
        address king_,
        address feeSink_,
        address owner_
    ) Ownable(owner_) {
        require(
            usdc_ != address(0) && oracle_ != address(0) && krt_ != address(0) && zkGate_ != address(0)
                && attest_ != address(0) && king_ != address(0) && feeSink_ != address(0),
            "ZERO"
        );
        usdc = IERC20(usdc_);
        oracle = IHotOracleND(oracle_);
        krt = krt_;
        zkGate = IZkGateND(zkGate_);
        attest = IBordersND(attest_);
        king = king_;
        feeSink = feeSink_;
    }

    /// @notice Diaspora USDC → 2% to HOT → net to Lagos agent (NGN P2P off-chain).
    /// @param agent Payout address (KYC'd off-chain). @param usdcAmount Gross USDC (6dp).
    function settleRemittance(address agent, uint256 usdcAmount)
        external
        nonReentrant
        whenZk
        returns (uint256 fee, uint256 net)
    {
        if (agent == address(0) || usdcAmount == 0) revert Zero();

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        fee = (usdcAmount * FEE_BPS) / BPS;
        net = usdcAmount - fee;

        if (fee > 0) usdc.safeTransfer(feeSink, fee);
        usdc.safeTransfer(agent, net);

        totalVolumeUsdc += usdcAmount;
        totalFeesUsdc += fee;
        unchecked {
            ++settleCount;
        }

        uint256 px = oracle.getPrice();
        emit RemittanceSettled(msg.sender, agent, usdcAmount, fee, net, px);
    }
}
