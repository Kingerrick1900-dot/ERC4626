// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Protocol ops credit in eUSD — Bound-proven draw to Landing.
/// @dev Solves the cold-start that kills most DeFi teams: pay ops from protocol credit
///      against attested collateral/reserves, without needing a VC USDC bankroll first.
///      Same pattern Maker used (generate Dai vs collateral → spend / build convert later).
///      Does NOT pull third-party USDC. Does NOT NAV-donate. King must set this as eUSD minter.

interface IBoundGateOps {
    function isProven(address who) external view returns (bool);
    function attestations(address who) external view returns (uint256 value, uint256 provenAt, bool valid);
    function minThreshold() external view returns (uint256);
}

interface IKingdomEusdOps {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

contract CrownOpsEusdDraw {
    uint256 public constant WAD = 1e18;
    /// @dev Bound attestation value is USDC 6dp; eUSD is 18dp.
    uint256 public constant EUSD_PER_USDC = 1e12;

    IBoundGateOps public immutable gate;
    IKingdomEusdOps public immutable eusd;
    address public immutable king;
    address public immutable landing;
    /// @notice Same spirit as Bound credit LLTV (e.g. 0.7e18 = 70%).
    uint256 public immutable lltv;

    uint256 public drawnEusd;
    address public operator;
    bool public paused;

    event Drawn(address indexed caller, uint256 amount, uint256 drawnTotal, address landing);
    event OperatorSet(address operator);
    event PauseSet(bool paused);

    error NotKing();
    error NotAuth();
    error NotProven();
    error BelowThreshold();
    error BadAmt();
    error Cap();
    error Paused();
    error NotMinter();

    modifier onlyKing() {
        if (msg.sender != king) revert NotKing();
        _;
    }

    constructor(address gate_, address eusd_, address king_, address landing_, uint256 lltv_) {
        require(gate_ != address(0) && eusd_ != address(0), "TOK");
        require(king_ != address(0) && landing_ != address(0), "ADDR");
        require(lltv_ > 0 && lltv_ <= WAD, "LLTV");
        gate = IBoundGateOps(gate_);
        eusd = IKingdomEusdOps(eusd_);
        king = king_;
        landing = landing_;
        lltv = lltv_;
        operator = king_;
    }

    function setOperator(address op) external onlyKing {
        require(op != address(0), "OP");
        operator = op;
        emit OperatorSet(op);
    }

    function setPaused(bool p) external onlyKing {
        paused = p;
        emit PauseSet(p);
    }

    /// @notice Max eUSD still drawable under Bound attestation × LLTV minus already drawn.
    function maxDraw() public view returns (uint256) {
        if (!gate.isProven(king)) return 0;
        (uint256 value,, bool valid) = gate.attestations(king);
        if (!valid || value < gate.minThreshold()) return 0;
        uint256 usdcCap = (value * lltv) / WAD;
        uint256 eusdCap = usdcCap * EUSD_PER_USDC;
        if (drawnEusd >= eusdCap) return 0;
        return eusdCap - drawnEusd;
    }

    /// @notice Mint eUSD to Landing as protocol ops credit (loan-shaped: Bound-capped).
    function draw(uint256 amount) external returns (uint256 landingBalHint) {
        if (paused) revert Paused();
        if (msg.sender != king && msg.sender != operator) revert NotAuth();
        if (amount == 0) revert BadAmt();
        if (!gate.isProven(king)) revert NotProven();
        (uint256 value,, bool valid) = gate.attestations(king);
        if (!valid || value < gate.minThreshold()) revert BelowThreshold();
        if (amount > maxDraw()) revert Cap();
        if (!eusd.isMinter(address(this))) revert NotMinter();

        drawnEusd += amount;
        eusd.mint(landing, amount);
        emit Drawn(msg.sender, amount, drawnEusd, landing);
        return amount;
    }
}
