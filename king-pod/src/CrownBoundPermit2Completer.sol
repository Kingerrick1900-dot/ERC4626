// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Track A PRIMARY — matcher USDC via Permit2 → credit.supply → Landing in one tx.
/// @dev Must be set as credit.operator. King must be gate.isProven.
///      Permit2 (Base): 0x000000000022D473030F116dDEE9F6B43aC78BA3

interface IERC20P2 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IBoundGateP2 {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256 value, uint256 provenAt, bool valid);
    function minThreshold() external view returns (uint256);
}

interface IZkCreditP2 {
    function supply(uint256 amount) external;
    function operatorBorrowTo(address to, uint256 amount) external;
    function maxBorrow(address) external view returns (uint256);
    function lltv() external view returns (uint256);
    function landing() external view returns (address);
    function king() external view returns (address);
    function gate() external view returns (address);
}

interface IAllowanceTransfer {
    struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    struct PermitSingle {
        PermitDetails details;
        address spender;
        uint256 sigDeadline;
    }

    function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external;

    function transferFrom(address from, address to, uint160 amount, address token) external;
}

contract CrownBoundPermit2Completer {
    IZkCreditP2 public immutable credit;
    IBoundGateP2 public immutable gate;
    IERC20P2 public immutable usdc;
    IAllowanceTransfer public immutable permit2;
    address public immutable king;
    address public immutable landing;

    event LoanCompleted(address indexed matcher, uint256 amount, uint256 landingUsdc);
    event LoanCompletedPermit2(address indexed matcher, uint256 amount, uint256 landingUsdc);

    error NotProven();
    error BelowThreshold();
    error BadAsk();
    error Pull();
    error LandingMiss();

    constructor(address credit_, address usdc_, address permit2_) {
        credit = IZkCreditP2(credit_);
        gate = IBoundGateP2(credit.gate());
        usdc = IERC20P2(usdc_);
        permit2 = IAllowanceTransfer(permit2_);
        king = credit.king();
        landing = credit.landing();
        require(king != address(0) && landing != address(0) && permit2_ != address(0), "CFG");
    }

    function maxAsk() public view returns (uint256) {
        (uint256 value,,) = gate.attestations(king);
        return (value * credit.lltv()) / 1e18;
    }

    /// @notice Classic ERC20 approve path (matcher approves this, then complete).
    function complete(uint256 amount) external returns (uint256 landingAfter) {
        _precheck(amount);
        require(_pullErc20(msg.sender, amount), "PULL");
        landingAfter = _fundAndDraw(amount);
        emit LoanCompleted(msg.sender, amount, landingAfter);
    }

    /// @notice Permit2 path: matcher signs PermitSingle (spender=this); we permit+pull+complete.
    /// @dev `amount` must be ≤ permit details.amount and ≤ maxAsk.
    function completeWithPermit2(
        address matcher,
        uint256 amount,
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    ) external returns (uint256 landingAfter) {
        _precheck(amount);
        require(matcher != address(0), "MATCHER");
        require(permitSingle.details.token == address(usdc), "TOKEN");
        require(permitSingle.spender == address(this), "SPENDER");
        require(uint256(permitSingle.details.amount) >= amount, "PERMIT_AMT");

        permit2.permit(matcher, permitSingle, signature);
        permit2.transferFrom(matcher, address(this), uint160(amount), address(usdc));

        landingAfter = _fundAndDraw(amount);
        emit LoanCompletedPermit2(matcher, amount, landingAfter);
    }

    /// @notice If matcher already set Permit2 allowance to this spender, pull without new sig.
    function completeWithPermit2Allowance(address matcher, uint256 amount)
        external
        returns (uint256 landingAfter)
    {
        _precheck(amount);
        require(matcher != address(0), "MATCHER");
        permit2.transferFrom(matcher, address(this), uint160(amount), address(usdc));
        landingAfter = _fundAndDraw(amount);
        emit LoanCompletedPermit2(matcher, amount, landingAfter);
    }

    function _precheck(uint256 amount) internal view {
        if (!gate.isProven(king)) revert NotProven();
        (uint256 value,,) = gate.attestations(king);
        if (value < gate.minThreshold()) revert BelowThreshold();
        if (amount == 0 || amount > maxAsk()) revert BadAsk();
    }

    function _pullErc20(address from, uint256 amount) internal returns (bool) {
        (bool ok, bytes memory data) = address(usdc).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, address(this), amount)
        );
        return ok && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _fundAndDraw(uint256 amount) internal returns (uint256 landingAfter) {
        require(usdc.approve(address(credit), amount), "APPROVE");
        credit.supply(amount);
        uint256 before = usdc.balanceOf(landing);
        credit.operatorBorrowTo(landing, amount);
        landingAfter = usdc.balanceOf(landing);
        if (landingAfter < before + amount) revert LandingMiss();
    }
}
