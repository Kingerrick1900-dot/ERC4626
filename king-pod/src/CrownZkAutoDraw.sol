// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Permissionless keeper: when ZK credit has USDC and King is proven, draw → Landing.
/// @dev Uses operatorBorrowTo so isProven checks King, not the keeper.
interface IZkGateA {
    function isProven(address account) external view returns (bool);
}

interface IZkCreditA {
    function maxBorrow(address account) external view returns (uint256);
    function operatorBorrowTo(address to, uint256 amount) external;
    function landing() external view returns (address);
    function king() external view returns (address);
    function gate() external view returns (address);
}

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
}

contract CrownZkAutoDraw {
    IZkCreditA public immutable credit;
    IZkGateA public immutable gate;
    address public immutable king;
    address public immutable landing;
    address public immutable usdc;

    event Drew(address indexed poker, uint256 amount, uint256 landingBal);

    constructor(address credit_, address usdc_) {
        credit = IZkCreditA(credit_);
        gate = IZkGateA(credit.gate());
        king = credit.king();
        landing = credit.landing();
        usdc = usdc_;
        require(landing != address(0) && king != address(0), "CFG");
    }

    /// @notice Draw full available maxBorrow for King to Landing. Permissionless.
    function poke() external returns (uint256 amount) {
        require(gate.isProven(king), "NOT_PROVEN");
        amount = credit.maxBorrow(king);
        require(amount > 0, "NO_LIQUIDITY");
        uint256 before = IERC20A(usdc).balanceOf(landing);
        credit.operatorBorrowTo(landing, amount);
        uint256 afterBal = IERC20A(usdc).balanceOf(landing);
        require(afterBal >= before + amount, "LANDING_MISS");
        emit Drew(msg.sender, amount, afterBal);
    }

    /// @notice Sized draw (operatorBorrowTo Landing).
    function pokeAmount(uint256 amount) external {
        require(gate.isProven(king), "NOT_PROVEN");
        uint256 maxB = credit.maxBorrow(king);
        require(amount > 0 && amount <= maxB, "SIZE");
        uint256 before = IERC20A(usdc).balanceOf(landing);
        credit.operatorBorrowTo(landing, amount);
        require(IERC20A(usdc).balanceOf(landing) >= before + amount, "LANDING_MISS");
        emit Drew(msg.sender, amount, IERC20A(usdc).balanceOf(landing));
    }

    function quote() external view returns (uint256 maxB, bool proven, uint256 creditUsdc) {
        proven = gate.isProven(king);
        maxB = credit.maxBorrow(king);
        creditUsdc = IERC20A(usdc).balanceOf(address(credit));
    }
}
