// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IEusdMint {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
    function burn(uint256 amt) external;
    function burnFrom(address from, uint256 amt) external;
}

/// @title CrownLsrEusd
/// @notice dForce LSR-class door: 1:1 USDC↔eUSD when reserves exist; mint payroll in eUSD.
/// @dev sellGem = USDC in → mint eUSD out. buyGem = eUSD in → USDC out from reserves.
///      Kingdom mint path (mintPayroll) needs no USDC — sovereign issue to Landing.
contract CrownLsrEusd is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public king;
    address public landing;
    bool public armed = true;
    mapping(address => bool) public operator; // CrownKingAgent / SpendVault

    uint256 public tin; // fee on sellGem (USDC→eUSD), 1e18 = 100%
    uint256 public tout; // fee on buyGem (eUSD→USDC)
    uint256 public totalSold; // USDC taken in
    uint256 public totalBought; // USDC paid out
    uint256 public totalPayrollMinted;

    event Armed(bool on);
    event LandingSet(address landing);
    event FeesSet(uint256 tin, uint256 tout);
    event OperatorSet(address op, bool on);
    event SellGem(address indexed user, uint256 usdcIn, uint256 eusdOut);
    event BuyGem(address indexed user, uint256 eusdIn, uint256 usdcOut);
    event PayrollMinted(address indexed to, uint256 amt);
    event KeepOpenSwept(uint256 usdcToLanding);

    error KingOnly();
    error NotArmed();
    error BadAmt();
    error NoReserves();
    error NotMinter();
    error LandingMiss();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    modifier onlyKingOrOp() {
        if (msg.sender != king && msg.sender != owner && !operator[msg.sender]) revert KingOnly();
        _;
    }

    constructor(address usdc_, address eusd_, address king_, address landing_, address owner_) Ownable(owner_) {
        require(usdc_ != address(0) && eusd_ != address(0) && king_ != address(0), "ZERO");
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        king = king_;
        landing = landing_;
        // 0 fees default — King can raise
    }

    function setArmed(bool on) external onlyKing {
        armed = on;
        emit Armed(on);
    }

    function setLanding(address landing_) external onlyKing {
        require(landing_ != address(0), "ZERO");
        landing = landing_;
        emit LandingSet(landing_);
    }

    function setFees(uint256 tin_, uint256 tout_) external onlyKing {
        require(tin_ <= 1e17 && tout_ <= 1e17, "FEE"); // max 10%
        tin = tin_;
        tout = tout_;
        emit FeesSet(tin_, tout_);
    }

    function setOperator(address op, bool on) external onlyKing {
        operator[op] = on;
        emit OperatorSet(op, on);
    }

    function usdcReserves() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /// @notice USDC → eUSD (1:1 minus tin). Requires this contract is eUSD minter OR king pre-funded eusd.
    function sellGem(uint256 usdcAmt) external nonReentrant returns (uint256 eusdOut) {
        if (!armed) revert NotArmed();
        if (usdcAmt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        uint256 fee = (usdcAmt * tin) / 1e18;
        eusdOut = usdcAmt - fee;
        // USDC is 6dp, eUSD is 18dp — scale
        eusdOut = eusdOut * 1e12;
        _mintEusd(msg.sender, eusdOut);
        totalSold += usdcAmt;
        emit SellGem(msg.sender, usdcAmt, eusdOut);
    }

    /// @notice eUSD → USDC from reserves (1:1 minus tout). Scales 18→6.
    function buyGem(uint256 eusdAmt) external nonReentrant returns (uint256 usdcOut) {
        if (!armed) revert NotArmed();
        if (eusdAmt == 0) revert BadAmt();
        eusd.safeTransferFrom(msg.sender, address(this), eusdAmt);
        // try burn if supported
        _tryBurn(eusdAmt);
        uint256 fee = (eusdAmt * tout) / 1e18;
        uint256 net = eusdAmt - fee;
        usdcOut = net / 1e12;
        if (usdcOut > usdcReserves()) revert NoReserves();
        usdc.safeTransfer(msg.sender, usdcOut);
        totalBought += usdcOut;
        emit BuyGem(msg.sender, eusdAmt, usdcOut);
    }

    /// @notice Sovereign payroll — mint eUSD to Landing (no USDC required).
    function mintPayroll(uint256 amt) external onlyKingOrOp nonReentrant {
        if (!armed) revert NotArmed();
        if (amt == 0) revert BadAmt();
        if (landing == address(0)) revert LandingMiss();
        _mintEusd(landing, amt);
        totalPayrollMinted += amt;
        emit PayrollMinted(landing, amt);
    }

    /// @notice Sweep USDC reserves to Landing (PSM keep-open harvest).
    function keepOpenSweep() external onlyKingOrOp nonReentrant returns (uint256 swept) {
        swept = usdcReserves();
        if (swept == 0) return 0;
        if (landing == address(0)) revert LandingMiss();
        usdc.safeTransfer(landing, swept);
        emit KeepOpenSwept(swept);
    }

    function _mintEusd(address to, uint256 amt) internal {
        IEusdMint m = IEusdMint(address(eusd));
        if (m.isMinter(address(this))) {
            m.mint(to, amt);
        } else if (m.isMinter(king)) {
            // pull pre-minted from king
            eusd.safeTransferFrom(king, to, amt);
        } else {
            revert NotMinter();
        }
    }

    function _tryBurn(uint256 amt) internal {
        // best-effort; if no burn, eUSD sits as protocol equity buffer
        (bool ok,) = address(eusd).call(abi.encodeWithSignature("burn(uint256)", amt));
        ok;
    }

    function sweep(address token, uint256 amt) external onlyKing {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
