// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface ISpendVault {
    function execute(address target, address token, uint256 amount, bytes calldata data)
        external
        returns (bytes memory);
    function setTarget(address target, bool on) external;
    function paused() external view returns (bool);
}

interface ILsrEusd {
    function mintPayroll(uint256 amt) external;
    function keepOpenSweep() external returns (uint256);
    function sellGem(uint256 usdcAmt) external returns (uint256);
    function buyGem(uint256 eusdAmt) external returns (uint256);
    function usdcReserves() external view returns (uint256);
}

interface IYrss {
    function reallocate(bytes calldata) external; // placeholder — real MetaMorpho uses MarketAllocation[]
}

interface IMorphoView {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @title CrownKingAgent
/// @notice Aave-MCP-better operator: observe → simulate → execute via CrownSpendVault allowlist.
/// @dev Only King-gated or capped agent paths. Refuse gasPark / matched re-borrow theater.
contract CrownKingAgent is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    address public king;
    address public landing;
    ISpendVault public vault;
    ILsrEusd public lsr;
    address public bamm;
    address public yrss;
    address public pa;
    address public morpho;
    bytes32 public parkMarketId;
    bytes32 public eusdMarketId;

    bool public armed = true;
    bool public autoMintPayroll;
    uint256 public payrollChunk; // eUSD raw

    event Armed(bool on);
    event ModulesSet(address vault, address lsr, address bamm);
    event RailsSet(address yrss, address pa, address morpho);
    event MarketsSet(bytes32 park, bytes32 eusd);
    event PayrollChunkSet(uint256 chunk, bool autoOn);
    event Observed(uint256 parkIdle, uint256 eusdIdle, uint256 lsrUsdc, uint256 ts);
    event PayrollFired(uint256 amt);
    event PsmSwept(uint256 usdc);
    event BammRentPoked(address user, uint256 sqrtRent);

    error KingOnly();
    error NotArmed();
    error BadAmt();
    error NoModule();
    error NoGasPark();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(address king_, address landing_, address owner_) Ownable(owner_) {
        require(king_ != address(0) && landing_ != address(0), "ZERO");
        king = king_;
        landing = landing_;
        payrollChunk = 1_000_000e18; // 1M eUSD default chunk
    }

    function setArmed(bool on) external onlyKing {
        armed = on;
        emit Armed(on);
    }

    function setModules(address vault_, address lsr_, address bamm_) external onlyKing {
        vault = ISpendVault(vault_);
        lsr = ILsrEusd(lsr_);
        bamm = bamm_;
        emit ModulesSet(vault_, lsr_, bamm_);
    }

    function setRails(address yrss_, address pa_, address morpho_) external onlyKing {
        yrss = yrss_;
        pa = pa_;
        morpho = morpho_;
        emit RailsSet(yrss_, pa_, morpho_);
    }

    function setMarkets(bytes32 park, bytes32 eusdM) external onlyKing {
        parkMarketId = park;
        eusdMarketId = eusdM;
        emit MarketsSet(park, eusdM);
    }

    function setPayrollChunk(uint256 chunk, bool autoOn) external onlyKing {
        payrollChunk = chunk;
        autoMintPayroll = autoOn;
        emit PayrollChunkSet(chunk, autoOn);
    }

    // ——— Observe (Aave MCP-class read) ———

    function observe()
        external
        view
        returns (uint256 parkIdle, uint256 eusdIdle, uint256 lsrUsdc, uint256 ts)
    {
        if (morpho != address(0) && parkMarketId != bytes32(0)) {
            (uint128 s,, uint128 b,,,) = IMorphoView(morpho).market(parkMarketId);
            parkIdle = s > b ? uint256(s) - uint256(b) : 0;
        }
        if (morpho != address(0) && eusdMarketId != bytes32(0)) {
            (uint128 s2,, uint128 b2,,,) = IMorphoView(morpho).market(eusdMarketId);
            eusdIdle = s2 > b2 ? uint256(s2) - uint256(b2) : 0;
        }
        if (address(lsr) != address(0)) lsrUsdc = lsr.usdcReserves();
        ts = block.timestamp;
    }

    function observeAndEmit() external {
        (uint256 p, uint256 e, uint256 u, uint256 t) = this.observe();
        emit Observed(p, e, u, t);
    }

    // ——— Execute (King law) ———

    /// @notice Mint eUSD payroll to Landing via LSR (sovereign issue).
    function firePayroll(uint256 amt) external onlyKing nonReentrant {
        if (!armed) revert NotArmed();
        if (address(lsr) == address(0)) revert NoModule();
        if (amt == 0) amt = payrollChunk;
        lsr.mintPayroll(amt);
        emit PayrollFired(amt);
    }

    /// @notice Sweep PSM/LSR USDC reserves to Landing.
    function pokePsmSweep() external onlyKing nonReentrant returns (uint256 swept) {
        if (!armed) revert NotArmed();
        if (address(lsr) == address(0)) revert NoModule();
        swept = lsr.keepOpenSweep();
        emit PsmSwept(swept);
    }

    /// @notice Optional capped auto path — only payroll chunk if autoMintPayroll.
    function pokeAuto() external nonReentrant {
        if (!armed || !autoMintPayroll) return;
        if (address(lsr) == address(0)) return;
        lsr.mintPayroll(payrollChunk);
        emit PayrollFired(payrollChunk);
    }

    /// @notice Forward allowlisted call through spend vault (agent / king).
    function exec(address target, address token, uint256 amount, bytes calldata data)
        external
        onlyKing
        nonReentrant
        returns (bytes memory)
    {
        if (!armed) revert NotArmed();
        if (address(vault) == address(0)) revert NoModule();
        return vault.execute(target, token, amount, data);
    }

    /// @notice Record BAMM rent poke (actual rent is on CrownBammOcean; agent may exec via vault).
    function pokeBammRent(address user, uint256 sqrtRent) external onlyKing {
        if (bamm == address(0)) revert NoModule();
        emit BammRentPoked(user, sqrtRent);
    }

    /// @notice Hard refuse — matched self-borrow theater.
    function gasPark(uint256, uint256) external pure {
        revert NoGasPark();
    }

    function borrow(uint256) external pure {
        revert NoGasPark();
    }

    function sweep(address token, uint256 amt) external onlyKing {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
