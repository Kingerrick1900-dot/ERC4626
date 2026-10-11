// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateHC {
    function isProven(address subject) external view returns (bool);
}

interface IBordersHC {
    function bordersSecure() external view returns (bool);
}

/// @notice Build 6d — China corridor settlement harvester. live=true from day one. Not gated.
/// @dev collectSettlement — 1.5% USDC fee → HOT. Rails: CIPS · parallel · RoyalCardNFC.
///      Parallel to Nigeria — no require(seeded).
contract HarvesterChina is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant FEE_BPS = 150; // 1.5%
    uint256 public constant BPS = 10_000;
    bool public constant live = true; // doctrine: not gated, not seeded

    IERC20 public immutable usdc;
    IZkGateHC public immutable zkGate;
    IBordersHC public immutable attest;
    address public immutable king;
    address public immutable hot;

    address public immutable krt;
    address public immutable oracle;
    address public immutable sovereignRail;
    address public immutable nigeriaDesk; // parallel rail — not a gate

    address public immutable cips;
    address public immutable parallelChain;
    address public immutable royalCard;

    uint256 public totalSettledUsdc;
    uint256 public totalFeesUsdc;
    uint256 public settleCount;
    mapping(address => bool) public bot;

    event SettlementCollected(
        address indexed counterparty, uint256 usdcGross, uint256 fee, uint256 net, bytes32 ref
    );
    event BotSet(address indexed bot, bool ok);

    error Auth();
    error Zero();
    error NotLive();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    modifier onlyBot() {
        if (!bot[msg.sender] && msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    struct Rails {
        address usdc;
        address zkGate;
        address attest;
        address king;
        address hot;
        address krt;
        address oracle;
        address sovereignRail;
        address nigeriaDesk;
        address cips;
        address parallelChain;
        address royalCard;
        address owner;
    }

    constructor(Rails memory r) Ownable(r.owner) {
        require(live, "NOT_LIVE"); // documents doctrine; constant true
        require(
            r.usdc != address(0) && r.zkGate != address(0) && r.attest != address(0) && r.king != address(0)
                && r.hot != address(0) && r.krt != address(0) && r.oracle != address(0)
                && r.sovereignRail != address(0) && r.nigeriaDesk != address(0) && r.cips != address(0)
                && r.parallelChain != address(0) && r.royalCard != address(0),
            "ZERO"
        );
        usdc = IERC20(r.usdc);
        zkGate = IZkGateHC(r.zkGate);
        attest = IBordersHC(r.attest);
        king = r.king;
        hot = r.hot;
        krt = r.krt;
        oracle = r.oracle;
        sovereignRail = r.sovereignRail;
        nigeriaDesk = r.nigeriaDesk;
        cips = r.cips;
        parallelChain = r.parallelChain;
        royalCard = r.royalCard;
        bot[r.owner] = true;
        bot[r.king] = true;
    }

    function setBot(address b, bool ok) external onlyOwner {
        bot[b] = ok;
        emit BotSet(b, ok);
    }

    /// @notice 1.5% settlement fee to HOT. Gross USDC pulled from msg.sender; net stays with counterparty path.
    /// @param counterparty Factory / buyer settlement subject (ops). @param usdcGross Gross settlement notional.
    function collectSettlement(address counterparty, uint256 usdcGross)
        external
        onlyBot
        nonReentrant
        whenZk
        returns (uint256 fee, uint256 net)
    {
        if (!live) revert NotLive(); // unreachable — doctrine lock
        if (counterparty == address(0) || usdcGross == 0) revert Zero();

        fee = (usdcGross * FEE_BPS) / BPS;
        net = usdcGross - fee;
        usdc.safeTransferFrom(msg.sender, address(this), usdcGross);
        if (fee > 0) usdc.safeTransfer(hot, fee);
        // net held for ops payout / rail settle — sweepable by Safe
        totalSettledUsdc += usdcGross;
        totalFeesUsdc += fee;
        unchecked {
            ++settleCount;
        }
        emit SettlementCollected(counterparty, usdcGross, fee, net, bytes32(0));
        return (fee, net);
    }

    function sweepNet(address to) external onlyOwner {
        if (to == address(0)) revert Zero();
        uint256 bal = usdc.balanceOf(address(this));
        if (bal == 0) revert Zero();
        usdc.safeTransfer(to, bal);
    }
}
