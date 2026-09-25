// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @title CrownBammOcean
/// @notice Frax-BAMM-inspired spike on eUSD/gUSD — oracle-free √(x·y) rent accounting.
/// @dev Self-contained xy=k book (not a Fraxswap dependency). Lenders deposit both legs;
///      borrowers post coll and rent liquidity measured in sqrt(K). Solvency ≤ 98% of vault √K.
contract CrownBammOcean is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_LTV_BPS = 9800; // 98% like Frax BAMM

    IERC20 public immutable token0; // gUSD
    IERC20 public immutable token1; // eUSD
    address public king;
    bool public armed = true;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalLenderShares;
    mapping(address => uint256) public lenderShares;

    struct Vault {
        uint256 coll0;
        uint256 coll1;
        uint256 rentedSqrt; // debt in √K units
    }

    mapping(address => Vault) public vaults;
    uint256 public totalRentedSqrt;
    uint256 public rentedMultiplier = WAD; // grows with interest (simple)

    event Armed(bool on);
    event Lent(address indexed user, uint256 amt0, uint256 amt1, uint256 shares);
    event Withdrawn(address indexed user, uint256 amt0, uint256 amt1, uint256 shares);
    event CollAdded(address indexed user, uint256 amt0, uint256 amt1);
    event Rented(address indexed user, uint256 sqrtRent, uint256 out0, uint256 out1);
    event Repaid(address indexed user, uint256 sqrtRepaid);

    error KingOnly();
    error NotArmed();
    error BadAmt();
    error Insolvent();
    error NoShares();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(address t0, address t1, address king_, address owner_) Ownable(owner_) {
        require(t0 != address(0) && t1 != address(0) && king_ != address(0), "ZERO");
        token0 = IERC20(t0);
        token1 = IERC20(t1);
        king = king_;
    }

    function setArmed(bool on) external onlyKing {
        armed = on;
        emit Armed(on);
    }

    function sqrtK() public view returns (uint256) {
        return _sqrt(reserve0 * reserve1);
    }

    /// @notice Seed / add lender liquidity (both sides). Shares ∝ √(amt0*amt1) on first deposit.
    function lend(uint256 amt0, uint256 amt1) external nonReentrant returns (uint256 shares) {
        if (!armed) revert NotArmed();
        if (amt0 == 0 || amt1 == 0) revert BadAmt();
        token0.safeTransferFrom(msg.sender, address(this), amt0);
        token1.safeTransferFrom(msg.sender, address(this), amt1);
        uint256 liq = _sqrt(amt0 * amt1);
        if (totalLenderShares == 0 || sqrtK() == 0) {
            shares = liq;
        } else {
            shares = (liq * totalLenderShares) / sqrtK();
        }
        if (shares == 0) revert BadAmt();
        reserve0 += amt0;
        reserve1 += amt1;
        totalLenderShares += shares;
        lenderShares[msg.sender] += shares;
        emit Lent(msg.sender, amt0, amt1, shares);
    }

    function withdrawLender(uint256 shares) external nonReentrant returns (uint256 amt0, uint256 amt1) {
        if (shares == 0 || shares > lenderShares[msg.sender]) revert NoShares();
        uint256 sk = sqrtK();
        require(sk > 0 && totalLenderShares > 0, "EMPTY");
        // leave buffer for rented
        amt0 = (shares * reserve0) / totalLenderShares;
        amt1 = (shares * reserve1) / totalLenderShares;
        lenderShares[msg.sender] -= shares;
        totalLenderShares -= shares;
        reserve0 -= amt0;
        reserve1 -= amt1;
        token0.safeTransfer(msg.sender, amt0);
        token1.safeTransfer(msg.sender, amt1);
        emit Withdrawn(msg.sender, amt0, amt1, shares);
    }

    function addCollateral(uint256 amt0, uint256 amt1) external nonReentrant {
        if (!armed) revert NotArmed();
        Vault storage v = vaults[msg.sender];
        if (amt0 > 0) {
            token0.safeTransferFrom(msg.sender, address(this), amt0);
            v.coll0 += amt0;
        }
        if (amt1 > 0) {
            token1.safeTransferFrom(msg.sender, address(this), amt1);
            v.coll1 += amt1;
        }
        emit CollAdded(msg.sender, amt0, amt1);
    }

    /// @notice Rent LP liquidity — pull proportional reserves; debt = √ rent in √K units.
    /// @dev Borrower must already hold vault collateral (addCollateral) covering rentedSqrt at ≤98% LTV.
    function rent(uint256 sqrtRent) external nonReentrant returns (uint256 out0, uint256 out1) {
        if (!armed) revert NotArmed();
        if (sqrtRent == 0) revert BadAmt();
        uint256 sk = sqrtK();
        require(sk > 0, "EMPTY");
        out0 = (sqrtRent * reserve0) / sk;
        out1 = (sqrtRent * reserve1) / sk;
        require(out0 > 0 && out1 > 0 && out0 <= reserve0 && out1 <= reserve1, "LIQ");
        Vault storage v = vaults[msg.sender];
        v.rentedSqrt += sqrtRent;
        totalRentedSqrt += sqrtRent;
        if (!_solvent(v)) {
            v.rentedSqrt -= sqrtRent;
            totalRentedSqrt -= sqrtRent;
            revert Insolvent();
        }
        reserve0 -= out0;
        reserve1 -= out1;
        token0.safeTransfer(msg.sender, out0);
        token1.safeTransfer(msg.sender, out1);
        emit Rented(msg.sender, sqrtRent, out0, out1);
    }

    function repay(uint256 amt0, uint256 amt1) external nonReentrant returns (uint256 sqrtRepaid) {
        Vault storage v = vaults[msg.sender];
        if (v.rentedSqrt == 0) revert BadAmt();
        if (amt0 > 0) token0.safeTransferFrom(msg.sender, address(this), amt0);
        if (amt1 > 0) token1.safeTransferFrom(msg.sender, address(this), amt1);
        sqrtRepaid = _sqrt(amt0 * amt1);
        if (sqrtRepaid > v.rentedSqrt) sqrtRepaid = v.rentedSqrt;
        v.rentedSqrt -= sqrtRepaid;
        totalRentedSqrt -= sqrtRepaid;
        reserve0 += amt0;
        reserve1 += amt1;
        emit Repaid(msg.sender, sqrtRepaid);
    }

    function isSolvent(address user) external view returns (bool) {
        return _solvent(vaults[user]);
    }

    function vaultSqrt(address user) public view returns (uint256) {
        Vault storage v = vaults[user];
        return _sqrt(v.coll0 * v.coll1);
    }

    function _solvent(Vault storage v) internal view returns (bool) {
        if (v.rentedSqrt == 0) return true;
        uint256 vs = _sqrt(v.coll0 * v.coll1);
        return v.rentedSqrt * 10_000 <= vs * MAX_LTV_BPS;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        z = x;
        uint256 y = (x + 1) / 2;
        while (y < z) {
            z = y;
            y = (x / y + y) / 2;
        }
    }

    function sweep(address token, uint256 amt) external onlyKing {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
