// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../core/Core.sol";

interface IEusdGold {
    function burn(address from, uint256 amt) external;
    function transferFrom(address from, address to, uint256 amt) external returns (bool);
    function isMinter(address) external view returns (bool);
}

interface IGoldOracle {
    /// @notice Morpho-scale price. kXAU @ $10 → 1e35 (8dp coll → 6dp USD via /1e36).
    function price() external view returns (uint256);
}

/// @notice Scroll Gold Rail PSM — eUSD at $1 gold parity.
/// @dev Redeems to USDC when reserved, or to kXAU at oracle weight when gold is seeded.
///      This is the module that forces the peg story: cheap DEX eUSD → redeem hard value.
contract CrownGoldParityPsm is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd; // 18dp Scroll eUSD
    IERC20 public immutable usdc; // 6dp
    IERC20 public immutable kxau; // 8dp
    IGoldOracle public immutable oracle;
    address public immutable landing;

    uint256 public constant WAD = 1e18;
    uint256 public constant ORACLE_SCALE = 1e36;

    event RedeemedUsdc(address indexed to, uint256 eusdIn, uint256 usdcOut);
    event RedeemedKxau(address indexed to, uint256 eusdIn, uint256 kxauOut);
    event UsdcSeeded(uint256 amt);
    event KxauSeeded(uint256 amt);
    event Swept(address indexed token, address indexed to, uint256 amt);

    error BadAmt();
    error Dry();
    error NotMinter();

    constructor(
        address eusd_,
        address usdc_,
        address kxau_,
        address oracle_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        require(eusd_ != address(0) && usdc_ != address(0) && kxau_ != address(0), "ZERO");
        require(oracle_ != address(0) && landing_ != address(0), "ZERO2");
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
        kxau = IERC20(kxau_);
        oracle = IGoldOracle(oracle_);
        landing = landing_;
    }

    function seedUsdc(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        emit UsdcSeeded(amt);
    }

    function seedKxau(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        kxau.safeTransferFrom(msg.sender, address(this), amt);
        emit KxauSeeded(amt);
    }

    /// @notice $1 eUSD → USDC 6dp (requires USDC reserves).
    function redeemUsdc(uint256 eusdAmt, address to) external nonReentrant returns (uint256 usdcOut) {
        if (eusdAmt == 0) revert BadAmt();
        if (to == address(0)) to = msg.sender;
        usdcOut = eusdAmt / 1e12;
        if (usdcOut == 0) revert BadAmt();
        if (usdc.balanceOf(address(this)) < usdcOut) revert Dry();

        _pullAndBurn(eusdAmt);
        usdc.safeTransfer(to, usdcOut);
        emit RedeemedUsdc(to, eusdAmt, usdcOut);
    }

    /// @notice $1 eUSD → kXAU at live gold oracle (requires kXAU reserves in this PSM).
    /// @dev eUSD 18dp USD notional → kXAU 8dp via oracle Morpho scale.
    function redeemKxau(uint256 eusdAmt, address to) external nonReentrant returns (uint256 kxauOut) {
        if (eusdAmt == 0) revert BadAmt();
        if (to == address(0)) to = msg.sender;

        // USD 6dp value of eUSD at $1
        uint256 usd6 = eusdAmt / 1e12;
        uint256 px = oracle.price(); // 1e35 for $10
        // kxau8 = usd6 * 1e36 / price
        kxauOut = (usd6 * ORACLE_SCALE) / px;
        if (kxauOut == 0) revert BadAmt();
        if (kxau.balanceOf(address(this)) < kxauOut) revert Dry();

        _pullAndBurn(eusdAmt);
        kxau.safeTransfer(to, kxauOut);
        emit RedeemedKxau(to, eusdAmt, kxauOut);
    }

    /// @notice Gold floor view: kXAU in PSM valued at oracle, in USD 6dp.
    function goldReserveUsd6() external view returns (uint256) {
        uint256 bal = kxau.balanceOf(address(this));
        return (bal * oracle.price()) / ORACLE_SCALE;
    }

    function usdcReserve() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function quoteKxau(uint256 eusdAmt) external view returns (uint256 kxauOut) {
        uint256 usd6 = eusdAmt / 1e12;
        kxauOut = (usd6 * ORACLE_SCALE) / oracle.price();
    }

    function sweep(address token, address to, uint256 amt) external onlyOwner nonReentrant {
        if (to == address(0)) to = landing;
        IERC20(token).safeTransfer(to, amt);
        emit Swept(token, to, amt);
    }

    function _pullAndBurn(uint256 eusdAmt) internal {
        // Prefer burn (minter). Fallback: hold inventory against reserves.
        eusd.safeTransferFrom(msg.sender, address(this), eusdAmt);
        if (IEusdGold(address(eusd)).isMinter(address(this))) {
            IEusdGold(address(eusd)).burn(address(this), eusdAmt);
        }
    }
}
