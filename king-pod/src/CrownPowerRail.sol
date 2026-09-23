// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IEusdPower {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
    function isMinter(address) external view returns (bool);
    function setMinter(address, bool) external;
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoPower {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IOraclePower {
    function price() external view returns (uint256);
}

/// @title CrownPowerRail
/// @notice Stance of power: kingdom mints eUSD, opens Morpho doors, ingests foreign stables,
///         vacuums any loan idle vs eUSD coll, sweeps Circle/DAI/EURC/USDbC to Landing.
/// @dev Freeze-gated via `armed`. HOT must `eusd.setMinter(rail, true)` once.
contract CrownPowerRail is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant ORACLE_SCALE = 1e36;
    uint256 public constant WAD = 1e18;
    uint256 public constant HAIRCUT_BPS = 9_500;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_STABLES = 8;
    uint256 public constant MAX_MARKETS = 32;

    IEusdPower public immutable eusd;
    IMorphoPower public immutable morpho;
    address public immutable king;
    address public landing;

    bool public armed = true;

    mapping(address => bool) public isStable; // USDC/DAI/EURC/USDbC…
    address[] public stables;

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    bytes32[] public harvestIds;
    mapping(bytes32 => MarketParams) public harvestMarkets;
    mapping(bytes32 => bool) public isHarvestMarket;

    uint256 public totalMinted;
    uint256 public totalIngested; // foreign stable raw sum (mixed decimals — event per token)
    uint256 public totalHarvested;

    event Armed(bool on);
    event LandingSet(address landing);
    event StableSet(address token, bool allowed);
    event Minted(address to, uint256 amt);
    event Ingested(address stable, uint256 amtIn, uint256 eusdOut, address to);
    event Exited(address stable, uint256 eusdIn, uint256 amtOut, address to);
    event MarketCreated(bytes32 id, address loan, address coll);
    event LoanSeeded(bytes32 id, uint256 eusdSupplied);
    event Harvested(bytes32 id, address loan, uint256 borrowed);
    event Swept(address token, uint256 amt, address to);

    error KingOnly();
    error NotArmed();
    error BadAmt();
    error BadToken();
    error NotMinter();
    error Dup();
    error TooMany();
    error IdleMiss();
    error BadParams();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    modifier whenArmed() {
        if (!armed) revert NotArmed();
        _;
    }

    constructor(address eusd_, address morpho_, address king_, address landing_, address owner_) Ownable(owner_) {
        if (eusd_ == address(0) || morpho_ == address(0) || king_ == address(0) || landing_ == address(0)) {
            revert BadAmt();
        }
        eusd = IEusdPower(eusd_);
        morpho = IMorphoPower(morpho_);
        king = king_;
        landing = landing_;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function setStable(address token, bool allowed) external onlyOwner {
        if (token == address(0) || token == address(eusd)) revert BadToken();
        if (allowed && !isStable[token]) {
            if (stables.length >= MAX_STABLES) revert TooMany();
            isStable[token] = true;
            stables.push(token);
            IERC20(token).safeApprove(address(morpho), type(uint256).max);
        } else if (!allowed && isStable[token]) {
            isStable[token] = false;
        }
        emit StableSet(token, allowed);
    }

    function stableCount() external view returns (uint256) {
        return stables.length;
    }

    // ─── SOVEREIGN MINT ─────────────────────────────────────────────

    /// @notice Mint eUSD to `to` (Landing / HOT / this). Requires rail isMinter.
    function mintEusd(address to, uint256 amt) external onlyKing whenArmed nonReentrant {
        if (to == address(0) || amt == 0) revert BadAmt();
        if (!eusd.isMinter(address(this))) revert NotMinter();
        eusd.mint(to, amt);
        totalMinted += amt;
        emit Minted(to, amt);
    }

    /// @notice Mint eUSD straight to Landing — kingdom payroll in sovereign USD units.
    function mintToLanding(uint256 amt) external onlyKing whenArmed nonReentrant {
        if (amt == 0) revert BadAmt();
        if (!eusd.isMinter(address(this))) revert NotMinter();
        eusd.mint(landing, amt);
        totalMinted += amt;
        emit Minted(landing, amt);
    }

    // ─── MULTI-STABLE INGEST (foreign Circle/DAI/EUR → eUSD) ────────

    /// @notice Pull foreign stable from king → mint equal eUSD (1:1 raw after decimal normalize to 18).
    /// @dev USDC/EURC/USDbC 6dp: eusdOut = amt * 1e12. DAI 18dp: eusdOut = amt.
    function ingestStable(address stable, uint256 amt, address eusdTo)
        external
        onlyKing
        whenArmed
        nonReentrant
        returns (uint256 eusdOut)
    {
        if (!isStable[stable] || amt == 0) revert BadToken();
        if (eusdTo == address(0)) eusdTo = landing;
        if (!eusd.isMinter(address(this))) revert NotMinter();

        IERC20(stable).safeTransferFrom(king, address(this), amt);
        eusdOut = _toEusdUnits(stable, amt);
        eusd.mint(eusdTo, eusdOut);
        totalMinted += eusdOut;
        totalIngested += amt;
        emit Ingested(stable, amt, eusdOut, eusdTo);
    }

    /// @notice Burn eUSD from king → send foreign stable out (requires inventory on rail).
    function exitStable(address stable, uint256 eusdIn, address to)
        external
        onlyKing
        whenArmed
        nonReentrant
        returns (uint256 amtOut)
    {
        if (!isStable[stable] || eusdIn == 0) revert BadToken();
        if (to == address(0)) to = landing;
        amtOut = _fromEusdUnits(stable, eusdIn);
        if (amtOut == 0 || IERC20(stable).balanceOf(address(this)) < amtOut) revert BadAmt();
        // pull + burn eUSD from king
        require(eusd.transferFrom(king, address(this), eusdIn), "EUSD_IN");
        eusd.burn(address(this), eusdIn);
        IERC20(stable).safeTransfer(to, amtOut);
        emit Exited(stable, eusdIn, amtOut, to);
    }

    // ─── MORPHO POWER DOORS ─────────────────────────────────────────

    /// @notice Create Morpho Blue market (loan/coll/oracle/irm/lltv). Idempotent if exists.
    function createMarket(MarketParams calldata mp) external onlyKing whenArmed returns (bytes32 id) {
        if (mp.loanToken == address(0) || mp.oracle == address(0) || mp.lltv == 0) revert BadParams();
        id = keccak256(abi.encode(mp));
        (address existing,,,,) = morpho.idToMarketParams(id);
        if (existing == address(0)) {
            morpho.createMarket(
                IMorphoPower.MarketParams(mp.loanToken, mp.collateralToken, mp.oracle, mp.irm, mp.lltv)
            );
            emit MarketCreated(id, mp.loanToken, mp.collateralToken);
        }
    }

    /// @notice Mint eUSD and supply as LOAN liquidity (king funds the borrowable side with sovereign mint).
    function mintSupplyLoan(bytes32 id, MarketParams calldata mp, uint256 eusdAmt)
        external
        onlyKing
        whenArmed
        nonReentrant
    {
        if (eusdAmt == 0) revert BadAmt();
        if (mp.loanToken != address(eusd)) revert BadParams();
        if (!eusd.isMinter(address(this))) revert NotMinter();
        bytes32 calc = keccak256(abi.encode(mp));
        if (calc != id) revert BadParams();

        eusd.mint(address(this), eusdAmt);
        totalMinted += eusdAmt;
        eusd.approve(address(morpho), eusdAmt);
        morpho.supply(
            IMorphoPower.MarketParams(mp.loanToken, mp.collateralToken, mp.oracle, mp.irm, mp.lltv),
            eusdAmt,
            0,
            address(this),
            ""
        );
        emit LoanSeeded(id, eusdAmt);
        emit Minted(address(this), eusdAmt);
    }

    function addHarvestMarket(bytes32 id) external onlyOwner {
        if (isHarvestMarket[id]) revert Dup();
        if (harvestIds.length >= MAX_MARKETS) revert TooMany();
        (address loan, address coll, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(id);
        if (loan == address(0) || lltv == 0) revert BadParams();
        harvestMarkets[id] = MarketParams(loan, coll, oracle, irm, lltv);
        isHarvestMarket[id] = true;
        harvestIds.push(id);
        IERC20(loan).safeApprove(address(morpho), type(uint256).max);
        if (coll != address(0)) IERC20(coll).safeApprove(address(morpho), type(uint256).max);
    }

    function idleOf(bytes32 id) public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(id);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Drain loan idle vs eUSD (or other) coll pulled from king → Landing.
    function harvest(bytes32 id, uint256 collAmt, uint256 maxLoan)
        external
        onlyKing
        whenArmed
        nonReentrant
        returns (uint256 borrowed)
    {
        if (!isHarvestMarket[id]) revert BadParams();
        MarketParams memory mp = harvestMarkets[id];
        IMorphoPower.MarketParams memory mmp =
            IMorphoPower.MarketParams(mp.loanToken, mp.collateralToken, mp.oracle, mp.irm, mp.lltv);
        uint256 idle = idleOf(id);
        if (idle == 0) revert IdleMiss();
        uint256 target = maxLoan == 0 ? idle : (maxLoan < idle ? maxLoan : idle);

        if (collAmt == 0) {
            uint256 px = IOraclePower(mp.oracle).price();
            if (px == 0) revert BadAmt();
            uint256 num = target * ORACLE_SCALE * WAD * BPS;
            uint256 den = px * mp.lltv * HAIRCUT_BPS;
            collAmt = (num + den - 1) / den;
            uint256 bal = IERC20(mp.collateralToken).balanceOf(king);
            if (collAmt > bal) collAmt = bal;
        }
        if (collAmt == 0) revert BadAmt();

        IERC20(mp.collateralToken).safeTransferFrom(king, address(this), collAmt);
        morpho.supplyCollateral(mmp, collAmt, address(this), "");

        uint256 value = collAmt * IOraclePower(mp.oracle).price() / ORACLE_SCALE;
        uint256 room = value * mp.lltv / WAD * HAIRCUT_BPS / BPS;
        borrowed = target < room ? target : room;
        if (borrowed == 0) revert IdleMiss();

        morpho.borrow(mmp, borrowed, 0, address(this), landing);
        totalHarvested += borrowed;
        emit Harvested(id, mp.loanToken, borrowed);
    }

    /// @notice Sweep any token on the rail (foreign stables after ingest) to Landing/king.
    function sweep(address token, uint256 amt, address to) external onlyKing nonReentrant {
        if (to == address(0)) to = landing;
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 send = amt == 0 ? bal : amt;
        if (send == 0) revert BadAmt();
        IERC20(token).safeTransfer(to, send);
        emit Swept(token, send, to);
    }

    function _toEusdUnits(address stable, uint256 amt) internal view returns (uint256) {
        uint8 d = IERC20(stable).decimals();
        if (d == 18) return amt;
        if (d < 18) return amt * (10 ** (18 - d));
        return amt / (10 ** (d - 18));
    }

    function _fromEusdUnits(address stable, uint256 eusdAmt) internal view returns (uint256) {
        uint8 d = IERC20(stable).decimals();
        if (d == 18) return eusdAmt;
        if (d < 18) return eusdAmt / (10 ** (18 - d));
        return eusdAmt * (10 ** (d - 18));
    }
}
