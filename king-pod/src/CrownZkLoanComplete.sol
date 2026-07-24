// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Atomic loan completion: matcher USDC → credit.supply → draw → Landing (one tx).
/// @dev King-side receive path fully engineered. Matcher only approve + complete(amount).
interface IERC20C {
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IZkGateC {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256 value, uint256 ts, uint256 flag);
    function minThreshold() external view returns (uint256);
}

interface IZkCreditC {
    function supply(uint256 amount) external;
    function borrow(uint256 amount) external;
    function maxBorrow(address) external view returns (uint256);
    function lltv() external view returns (uint256);
    function landing() external view returns (address);
    function king() external view returns (address);
    function gate() external view returns (address);
    function setOperator(address, bool) external;
    function operator(address) external view returns (bool);
}

contract CrownZkLoanComplete {
    IZkCreditC public immutable credit;
    IZkGateC public immutable gate;
    IERC20C public immutable usdc;
    address public immutable king;
    address public immutable landing;

    event LoanCompleted(address indexed matcher, uint256 amount, uint256 landingUsdc);

    constructor(address credit_, address usdc_) {
        credit = IZkCreditC(credit_);
        gate = IZkGateC(credit.gate());
        usdc = IERC20C(usdc_);
        king = credit.king();
        landing = credit.landing();
        require(king != address(0) && landing != address(0), "CFG");
    }

    function maxAsk() public view returns (uint256) {
        (uint256 value,,) = gate.attestations(king);
        return value * credit.lltv() / 1e18;
    }

    /// @notice Matcher: approve this contract for `amount` USDC, then complete.
    function complete(uint256 amount) external returns (uint256 landingAfter) {
        require(gate.isProven(king), "NOT_PROVEN");
        (uint256 value,,) = gate.attestations(king);
        require(value >= gate.minThreshold(), "BELOW_THRESHOLD");
        require(amount > 0 && amount <= maxAsk(), "ASK");

        require(usdc.transferFrom(msg.sender, address(this), amount), "PULL");
        require(usdc.approve(address(credit), amount), "APPROVE");
        credit.supply(amount);

        uint256 before = usdc.balanceOf(landing);
        // Must be operator on credit (set at deploy by King)
        credit.borrow(amount);
        landingAfter = usdc.balanceOf(landing);
        require(landingAfter >= before + amount, "LANDING");

        emit LoanCompleted(msg.sender, amount, landingAfter);
    }
}
