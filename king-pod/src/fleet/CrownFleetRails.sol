// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownBorrowCapacity} from "./CrownBorrowCapacity.sol";

interface IPsmSeedFleet {
    function seedUsdc(uint256 amt) external;
    function usdcReserve() external view returns (uint256);
}

interface IGusdBal {
    function balanceOf(address) external view returns (uint256);
}

interface ISwapAdapter {
    /// @notice Swap exact eUSD → USDC to `to`. Returns USDC out (6dp).
    function swapEusdToUsdc(uint256 eusdIn, uint256 minUsdcOut, address to) external returns (uint256 usdcOut);
}

/// @notice At HOT gUSD ≥ trigger, swap buffer eUSD → real USDC → seed PSM → enable toll.
/// @dev No fake USDC. If adapter unset and no USDC on hot, reverts NeedFx.
contract TollBoothAutoSeeder is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    IERC20 public immutable usdc;
    IGusdBal public immutable gusd;
    IPsmSeedFleet public immutable psm;
    address public immutable king;

    uint256 public hotTrigger; // 250M gUSD
    uint256 public swapEusdAmt; // 2M eUSD buffer
    uint256 public targetPsmDepth; // 10M USDC (6dp)
    uint256 public tollBps; // 10 = 0.1%
    bool public armed;
    bool public seeded;
    ISwapAdapter public swapAdapter;

    event Armed(bool on);
    event AdapterSet(address indexed adapter);
    event Seeded(uint256 usdcIn, uint256 psmReserve);
    event TollSet(uint256 bps);

    error NeedFx();
    error NotArmed();
    error AlreadySeeded();
    error TriggerMiss();

    constructor(
        address eusd_,
        address usdc_,
        address gusd_,
        address psm_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
        gusd = IGusdBal(gusd_);
        psm = IPsmSeedFleet(psm_);
        king = king_;
        hotTrigger = 250_000_000e18;
        swapEusdAmt = 2_000_000e18;
        targetPsmDepth = 10_000_000e6;
        tollBps = 10;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setAdapter(address a) external onlyOwner {
        swapAdapter = ISwapAdapter(a);
        emit AdapterSet(a);
    }

    function setParams(uint256 hotTrigger_, uint256 swapEusdAmt_, uint256 targetPsmDepth_, uint256 tollBps_)
        external
        onlyOwner
    {
        hotTrigger = hotTrigger_;
        swapEusdAmt = swapEusdAmt_;
        targetPsmDepth = targetPsmDepth_;
        tollBps = tollBps_;
        emit TollSet(tollBps_);
    }

    function canSeed() public view returns (bool) {
        return armed && !seeded && gusd.balanceOf(king) >= hotTrigger;
    }

    /// @notice Pull eUSD from king → swap via adapter (or use pre-funded USDC) → seed PSM.
    function execSeed() external onlyOwner nonReentrant {
        if (!armed) revert NotArmed();
        if (seeded) revert AlreadySeeded();
        if (gusd.balanceOf(king) < hotTrigger) revert TriggerMiss();

        uint256 usdcGot = usdc.balanceOf(address(this));
        if (usdcGot < targetPsmDepth) {
            if (address(swapAdapter) == address(0)) revert NeedFx();
            uint256 needEusd = swapEusdAmt;
            eusd.safeTransferFrom(king, address(this), needEusd);
            eusd.approve(address(swapAdapter), needEusd);
            uint256 minOut = (targetPsmDepth * 95) / 100; // 5% slip room
            usdcGot += swapAdapter.swapEusdToUsdc(needEusd, minOut, address(this));
        }
        if (usdcGot == 0) revert NeedFx();

        uint256 seedAmt = usdcGot > targetPsmDepth ? targetPsmDepth : usdcGot;
        usdc.approve(address(psm), seedAmt);
        psm.seedUsdc(seedAmt);
        seeded = true;
        emit Seeded(seedAmt, psm.usdcReserve());
    }
}

/// @notice Auto-issue Kingdom Gold Notes when Morpho **borrow capacity** ≥ trigger.
/// @dev Gate = coll × oracle × LLTV − debt (loan units). NOT psm.usdcReserve / wallet dust.
/// Borrower posts RSS; King RSS never sold. Notes = debt receipts at fixed APR.
contract NoteIssuerAuto is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    string public constant name = "Kingdom Gold Note";
    string public constant symbol = "KGN";
    uint8 public constant decimals = 18;

    IERC20 public immutable rss;
    IPsmSeedFleet public immutable psm; // retained for FX settlement surface; not the issue gate
    address public immutable king;
    address public immutable morpho;
    bytes32 public immutable capacityMarketId; // RSS/USDC Morpho book

    uint256 public capacityTrigger; // 10M USDC (6dp) borrow headroom
    uint256 public noteSize; // 1M (18dp face)
    uint256 public maxNotes; // 20
    uint256 public aprBps; // 500 = 5%
    uint256 public collPerNote; // borrower RSS lock per note
    uint256 public notesIssued;
    bool public armed;

    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public noteBorrower;
    mapping(uint256 => uint256) public noteColl;
    uint256 public totalSupply;

    event Armed(bool on);
    event NoteIssued(uint256 indexed id, address indexed borrower, uint256 face, uint256 rssLocked);
    event NoteRepaid(uint256 indexed id, address indexed borrower);
    event CapacityTriggerSet(uint256 trigger);

    error NotArmed();
    error CapacityMiss();
    error Cap();
    error BadAmt();

    constructor(
        address rss_,
        address psm_,
        address king_,
        address morpho_,
        bytes32 capacityMarketId_,
        address owner_
    ) Ownable(owner_) {
        require(morpho_ != address(0) && capacityMarketId_ != bytes32(0), "ZERO");
        rss = IERC20(rss_);
        psm = IPsmSeedFleet(psm_);
        king = king_;
        morpho = morpho_;
        capacityMarketId = capacityMarketId_;
        capacityTrigger = 10_000_000e6;
        noteSize = 1_000_000e18;
        maxNotes = 20;
        aprBps = 500;
        collPerNote = 1_000 ether;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setParams(
        uint256 capacityTrigger_,
        uint256 noteSize_,
        uint256 maxNotes_,
        uint256 aprBps_,
        uint256 collPerNote_
    ) external onlyOwner {
        capacityTrigger = capacityTrigger_;
        noteSize = noteSize_;
        maxNotes = maxNotes_;
        aprBps = aprBps_;
        collPerNote = collPerNote_;
        emit CapacityTriggerSet(capacityTrigger_);
    }

    /// @notice King Morpho additional borrowable USDC (6dp) on capacity market.
    function borrowCapacity() public view returns (uint256) {
        return CrownBorrowCapacity.borrowCapacity(morpho, capacityMarketId, king);
    }

    function canIssue() public view returns (bool) {
        return armed && borrowCapacity() >= capacityTrigger && notesIssued < maxNotes;
    }

    /// @notice Borrower locks their RSS; receives note face receipt. King bag untouched.
    function issueNote(address borrower) external onlyOwner nonReentrant returns (uint256 id) {
        if (!armed) revert NotArmed();
        if (borrowCapacity() < capacityTrigger) revert CapacityMiss();
        if (notesIssued >= maxNotes) revert Cap();
        if (borrower == address(0)) revert BadAmt();

        rss.safeTransferFrom(borrower, address(this), collPerNote);
        id = notesIssued;
        noteBorrower[id] = borrower;
        noteColl[id] = collPerNote;
        balanceOf[borrower] += noteSize;
        totalSupply += noteSize;
        notesIssued += 1;
        emit NoteIssued(id, borrower, noteSize, collPerNote);
    }
}

/// @notice Scroll RSS boot token — same face as Base elephanToken/RSS (new address on Scroll).
contract CrownScrollRss is Ownable {
    string public constant name = "elephanToken";
    string public constant symbol = "RSS";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isMinter;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event MinterSet(address indexed m, bool on);

    constructor(address owner_, address mintTo, uint256 genesis) Ownable(owner_) {
        isMinter[owner_] = true;
        if (genesis > 0 && mintTo != address(0)) {
            totalSupply = genesis;
            balanceOf[mintTo] = genesis;
            emit Transfer(address(0), mintTo, genesis);
        }
    }

    function setMinter(address m, bool on) external onlyOwner {
        isMinter[m] = on;
        emit MinterSet(m, on);
    }

    function mint(address to, uint256 amt) external {
        require(isMinter[msg.sender], "MINTER");
        require(amt > 0, "AMT");
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        emit Approval(msg.sender, spender, amt);
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        return _transfer(msg.sender, to, amt);
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            require(a >= amt, "ALLOW");
            allowance[from][msg.sender] = a - amt;
        }
        return _transfer(from, to, amt);
    }

    function _transfer(address from, address to, uint256 amt) internal returns (bool) {
        require(to != address(0) && balanceOf[from] >= amt, "BAL");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
        return true;
    }
}
