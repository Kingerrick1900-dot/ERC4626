// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkCreditLadder {
    function operatorBorrowTo(address to, uint256 amt) external;
    function maxBorrow(address user) external view returns (uint256);
    function supply(uint256 amt) external;
    function setOperator(address op, bool allowed) external;
}

interface IERC4626Vault {
    function asset() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function maxRedeem(address owner) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Multi-rung yield ladder: ZK-credit draw → ERC4626 yield → harvest → next rung / deepen L / refresh capital.
/// @dev Borrow from Kingdom ZK credit is 0% interest; yield venues pay carry. Cold Landing optional.
contract CrownZkYieldLadder is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    address public immutable king;
    address public landing;
    IZkCreditLadder public credit;

    struct Rung {
        IERC4626Vault vault;
        uint16 weightBps; // of each draw allocation
        bool active;
    }

    Rung[] public rungs;
    uint256 public totalDrawn;
    uint256 public totalHarvested;

    event CreditSet(address credit);
    event LandingSet(address landing);
    event RungSet(uint256 indexed idx, address vault, uint16 weightBps, bool active);
    event Drawn(uint256 amt);
    event Allocated(uint256 indexed rung, uint256 assets, uint256 shares);
    event Harvested(uint256 indexed rung, uint256 assets);
    event Deepened(uint256 amt);
    event ToLanding(uint256 amt);

    error Bad();
    error Empty();

    constructor(address usdc_, address king_, address landing_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        king = king_;
        landing = landing_;
    }

    function setCredit(address credit_) external onlyOwner {
        credit = IZkCreditLadder(credit_);
        emit CreditSet(credit_);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert Bad();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function addRung(address vault, uint16 weightBps) external onlyOwner {
        if (vault == address(0) || weightBps == 0) revert Bad();
        if (IERC4626Vault(vault).asset() != address(usdc)) revert Bad();
        rungs.push(Rung({vault: IERC4626Vault(vault), weightBps: weightBps, active: true}));
        emit RungSet(rungs.length - 1, vault, weightBps, true);
    }

    function setRung(uint256 idx, uint16 weightBps, bool active) external onlyOwner {
        if (idx >= rungs.length) revert Bad();
        rungs[idx].weightBps = weightBps;
        rungs[idx].active = active;
        emit RungSet(idx, address(rungs[idx].vault), weightBps, active);
    }

    function rungCount() external view returns (uint256) {
        return rungs.length;
    }

    /// @notice Draw `amt` from ZK credit into this ladder (must be credit operator; king proven).
    function drawFromCredit(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0 || address(credit) == address(0)) revert Bad();
        credit.operatorBorrowTo(address(this), amt);
        totalDrawn += amt;
        emit Drawn(amt);
    }

    /// @notice Draw max available from credit into ladder.
    function drawMaxFromCredit() external onlyOwner nonReentrant returns (uint256 amt) {
        if (address(credit) == address(0)) revert Bad();
        amt = credit.maxBorrow(king);
        if (amt == 0) revert Empty();
        credit.operatorBorrowTo(address(this), amt);
        totalDrawn += amt;
        emit Drawn(amt);
    }

    /// @notice King/ops can seed ladder with idle USDC (e.g. Landing slice) without credit draw.
    function seed(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert Bad();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
    }

    /// @notice Allocate idle USDC across active rungs by weightBps.
    function allocateIdle() external onlyOwner nonReentrant {
        uint256 bal = usdc.balanceOf(address(this));
        if (bal == 0) revert Empty();
        uint256 wsum;
        uint256 last;
        for (uint256 i; i < rungs.length; i++) {
            if (rungs[i].active && rungs[i].weightBps > 0) {
                wsum += rungs[i].weightBps;
                last = i;
            }
        }
        if (wsum == 0) revert Bad();
        uint256 allocated;
        for (uint256 i; i < rungs.length; i++) {
            if (!rungs[i].active || rungs[i].weightBps == 0) continue;
            uint256 slice;
            if (i == last) {
                slice = bal - allocated;
            } else {
                slice = (bal * rungs[i].weightBps) / wsum;
            }
            if (slice == 0) continue;
            usdc.safeApprove(address(rungs[i].vault), slice);
            uint256 shares = rungs[i].vault.deposit(slice, address(this));
            allocated += slice;
            emit Allocated(i, slice, shares);
        }
    }

    /// @notice Harvest one rung fully to ladder idle USDC.
    function harvest(uint256 idx) external onlyOwner nonReentrant returns (uint256 assets) {
        if (idx >= rungs.length) revert Bad();
        IERC4626Vault v = rungs[idx].vault;
        uint256 shares = v.maxRedeem(address(this));
        if (shares == 0) revert Empty();
        assets = v.redeem(shares, address(this), address(this));
        totalHarvested += assets;
        emit Harvested(idx, assets);
    }

    /// @notice Harvest all rungs.
    function harvestAll() external onlyOwner nonReentrant returns (uint256 total) {
        for (uint256 i; i < rungs.length; i++) {
            IERC4626Vault v = rungs[i].vault;
            uint256 shares = v.maxRedeem(address(this));
            if (shares == 0) continue;
            uint256 assets = v.redeem(shares, address(this), address(this));
            total += assets;
            emit Harvested(i, assets);
        }
        totalHarvested += total;
    }

    /// @notice Reinvest idle USDC back into credit pool L (deepens system liquidity for next draws).
    function deepenCredit(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0 || address(credit) == address(0)) revert Bad();
        uint256 bal = usdc.balanceOf(address(this));
        if (amt > bal) amt = bal;
        usdc.safeApprove(address(credit), amt);
        credit.supply(amt);
        emit Deepened(amt);
    }

    function sendLanding(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert Bad();
        usdc.safeTransfer(landing, amt);
        emit ToLanding(amt);
    }

    function rungAssets(uint256 idx) external view returns (uint256) {
        if (idx >= rungs.length) return 0;
        IERC4626Vault v = rungs[idx].vault;
        return v.convertToAssets(v.balanceOf(address(this)));
    }
}
