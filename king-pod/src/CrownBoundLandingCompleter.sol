// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Matcher path on the bound-gate stack: pull USDC → credit.supply → operatorBorrowTo(Landing).
/// @dev Requires this contract set as credit.operator. King must be gate.isProven.
interface IERC20L {
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IBoundGateL {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256 value, uint256 provenAt, bool valid);
    function minThreshold() external view returns (uint256);
}

interface IZkCreditL {
    function supply(uint256 amount) external;
    function operatorBorrowTo(address to, uint256 amount) external;
    function maxBorrow(address) external view returns (uint256);
    function lltv() external view returns (uint256);
    function landing() external view returns (address);
    function king() external view returns (address);
    function gate() external view returns (address);
}

contract CrownBoundLandingCompleter {
    IZkCreditL public immutable credit;
    IBoundGateL public immutable gate;
    IERC20L public immutable usdc;
    address public immutable king;
    address public immutable landing;

    event LoanCompleted(address indexed matcher, uint256 amount, uint256 landingUsdc);

    constructor(address credit_, address usdc_) {
        credit = IZkCreditL(credit_);
        gate = IBoundGateL(credit.gate());
        usdc = IERC20L(usdc_);
        king = credit.king();
        landing = credit.landing();
        require(king != address(0) && landing != address(0), "CFG");
    }

    function maxAsk() public view returns (uint256) {
        (uint256 value,,) = gate.attestations(king);
        return value * credit.lltv() / 1e18;
    }

    /// @notice Matcher: approve this for `amount` USDC, then complete → Landing.
    function complete(uint256 amount) external returns (uint256 landingAfter) {
        require(gate.isProven(king), "NOT_PROVEN");
        (uint256 value,,) = gate.attestations(king);
        require(value >= gate.minThreshold(), "BELOW_THRESHOLD");
        require(amount > 0 && amount <= maxAsk(), "ASK");

        require(usdc.transferFrom(msg.sender, address(this), amount), "PULL");
        require(usdc.approve(address(credit), amount), "APPROVE");
        credit.supply(amount);

        uint256 before = usdc.balanceOf(landing);
        credit.operatorBorrowTo(landing, amount);
        landingAfter = usdc.balanceOf(landing);
        require(landingAfter >= before + amount, "LANDING");

        emit LoanCompleted(msg.sender, amount, landingAfter);
    }
}
