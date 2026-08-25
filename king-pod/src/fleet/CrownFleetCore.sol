// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IMorphoFleet {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
    function setAuthorization(address, bool) external;
}

interface IBoundGateFleet {
    function isProven(address) external view returns (bool);
    function minThreshold() external view returns (uint256);
    function attestations(address) external view returns (uint256, uint256, bool);
}

interface IMintEusd {
    function mint(address to, uint256 amt) external;
}

interface IGusdWrap {
    function wrap(uint256 amt, address to) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Fleet AMO: mint→unmatched supply idle; operator slot for SupplyAmoBot / Gelato.
contract CrownSovereignAmoFleet is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoFleet public immutable morpho;
    IERC20 public immutable loan; // eUSD or gUSD
    IERC20 public immutable rss;
    IBoundGateFleet public immutable gate;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoFleet.MarketParams public mp;

    bool public requireGate;
    mapping(address => bool) public isOperator;

    uint256 public lastSupply;
    uint256 public lastBorrow;

    event AmoSupplied(uint256 amt, uint256 idleAfter);
    event CollPosted(uint256 rssAmt);
    event Borrowed(uint256 amt, address receiver, uint256 idleAfter);
    event OperatorSet(address indexed op, bool on);
    event GateToggled(bool on);

    error OnlyKing();
    error BadAmt();
    error IdleMiss();
    error GateMiss();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner && msg.sender != landing && !isOperator[msg.sender]) {
            revert OnlyKing();
        }
        _;
    }

    constructor(
        address morpho_,
        address loan_,
        address rss_,
        address gate_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoFleet(morpho_);
        loan = IERC20(loan_);
        rss = IERC20(rss_);
        gate = IBoundGateFleet(gate_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoFleet.MarketParams({
            loanToken: loan_, collateralToken: rss_, oracle: oracle_, irm: irm_, lltv: lltv_
        });
        requireGate = gate_ != address(0);
    }

    function setOperator(address op, bool on) external onlyOwner {
        isOperator[op] = on;
        emit OperatorSet(op, on);
    }

    function setRequireGate(bool on) external onlyOwner {
        requireGate = on;
        emit GateToggled(on);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function packReady() public view returns (bool) {
        if (!requireGate) return true;
        if (!gate.isProven(king)) return false;
        (uint256 v,, bool valid) = gate.attestations(king);
        return valid && v >= gate.minThreshold();
    }

    function book() external view returns (uint256 idleLoan, uint256 supply, uint256 borrow, bool proven) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        supply = s;
        borrow = b;
        idleLoan = idle();
        proven = packReady();
    }

    function supplyAmo(address from, uint256 amt) external onlyKing nonReentrant {
        if (amt == 0) revert BadAmt();
        loan.safeTransferFrom(from, address(this), amt);
        loan.approve(address(morpho), amt);
        morpho.supply(mp, amt, 0, landing, "");
        lastSupply = amt;
        emit AmoSupplied(amt, idle());
    }

    function postCollateral(uint256 rssAmt) external onlyKing nonReentrant {
        if (rssAmt == 0) rssAmt = rss.balanceOf(king);
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(king, address(this), rssAmt);
        rss.approve(address(morpho), rssAmt);
        morpho.supplyCollateral(mp, rssAmt, king, "");
        emit CollPosted(rssAmt);
    }

    function borrowLoan(uint256 amt, address receiver) external onlyKing nonReentrant returns (uint256) {
        if (amt == 0) revert BadAmt();
        if (!packReady()) revert GateMiss();
        morpho.accrueInterest(mp);
        if (idle() < amt) revert IdleMiss();
        if (receiver == address(0)) receiver = king;
        morpho.borrow(mp, amt, 0, king, receiver);
        lastBorrow = amt;
        emit Borrowed(amt, receiver, idle());
        return amt;
    }
}

/// @notice Minimal exit twin for fleet books.
contract CrownSovereignExitFleet is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoFleet public immutable morpho;
    IERC20 public immutable loan;
    IERC20 public immutable rss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoFleet.MarketParams public mp;

    constructor(
        address morpho_,
        address loan_,
        address rss_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoFleet(morpho_);
        loan = IERC20(loan_);
        rss = IERC20(rss_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoFleet.MarketParams({
            loanToken: loan_, collateralToken: rss_, oracle: oracle_, irm: irm_, lltv: lltv_
        });
    }
}

/// @notice Factory: spin RSS/loan books @ $50k, clone AMO+Exit, register for bot.
contract SovereignIdleFactory is Ownable {
    IMorphoFleet public immutable morpho;
    address public immutable rss;
    address public immutable gate;
    address public immutable king;
    address public immutable landing;
    address public immutable irm;
    uint256 public immutable lltv;

    struct Book {
        bytes32 marketId;
        address loan;
        address oracle;
        address amo;
        address exit;
        bool gusdFace;
    }

    Book[] public books;
    mapping(bytes32 => uint256) public bookIndex; // 1-based

    event BookOpened(bytes32 indexed marketId, address loan, address oracle, address amo, address exit, bool gusdFace);

    constructor(
        address morpho_,
        address rss_,
        address gate_,
        address king_,
        address landing_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoFleet(morpho_);
        rss = rss_;
        gate = gate_;
        king = king_;
        landing = landing_;
        irm = irm_;
        lltv = lltv_;
    }

    function bookCount() external view returns (uint256) {
        return books.length;
    }

    /// @notice Open a Morpho book with a fresh $50k oracle clone address (unique market id).
    function openBook(address loan, address oracle, bool gusdFace)
        external
        onlyOwner
        returns (bytes32 mid, address amo, address exit)
    {
        require(loan != address(0) && oracle != address(0), "ZERO");
        IMorphoFleet.MarketParams memory mp = IMorphoFleet.MarketParams({
            loanToken: loan, collateralToken: rss, oracle: oracle, irm: irm, lltv: lltv
        });
        morpho.createMarket(mp);
        mid = keccak256(abi.encode(mp));

        CrownSovereignAmoFleet amoC = new CrownSovereignAmoFleet(
            address(morpho), loan, rss, gate, king, landing, mid, oracle, irm, lltv, landing
        );
        CrownSovereignExitFleet exitC = new CrownSovereignExitFleet(
            address(morpho), loan, rss, king, landing, mid, oracle, irm, lltv, king
        );
        amo = address(amoC);
        exit = address(exitC);

        books.push(Book({marketId: mid, loan: loan, oracle: oracle, amo: amo, exit: exit, gusdFace: gusdFace}));
        bookIndex[mid] = books.length;
        emit BookOpened(mid, loan, oracle, amo, exit, gusdFace);
    }

    /// @notice Register an already-live book (e.g. PR #126 eUSD/gUSD) into the fleet index.
    function registerBook(bytes32 mid, address loan, address oracle, address amo, address exit, bool gusdFace)
        external
        onlyOwner
    {
        require(bookIndex[mid] == 0, "EXISTS");
        books.push(Book({marketId: mid, loan: loan, oracle: oracle, amo: amo, exit: exit, gusdFace: gusdFace}));
        bookIndex[mid] = books.length;
        emit BookOpened(mid, loan, oracle, amo, exit, gusdFace);
    }
}

/// @notice Keeper tick: mint eUSD → supplyAmo → borrow → optional wrap to gUSD. Toward target HOT.
/// @dev Works on fleet AMOs (operator) OR legacy AMO when called path uses king key via script.
contract SupplyAmoBot is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    IGusdWrap public immutable gusd;
    address public immutable king;
    address public immutable landing;
    address public keeper; // Gelato / King cron

    uint256 public tickMint; // default 10M
    uint256 public borrowBps; // 7000 = 70%
    uint256 public wrapBps; // 9000 = 90% of borrowed eUSD
    uint256 public targetHotGusd; // 1B
    uint256 public ticksDone;
    uint256 public mintedTotal;

    address public primaryAmo; // eUSD fleet/legacy AMO
    bool public primaryIsFleet;

    event Tick(uint256 minted, uint256 borrowed, uint256 wrapped, uint256 hotGusd);
    event KeeperSet(address indexed k);
    event PrimaryAmoSet(address indexed amo, bool fleet);

    error OnlyKeeper();
    error TargetHit();
    error BadAmo();

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner && msg.sender != king) revert OnlyKeeper();
        _;
    }

    constructor(
        address eusd_,
        address gusd_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        eusd = IERC20(eusd_);
        gusd = IGusdWrap(gusd_);
        king = king_;
        landing = landing_;
        keeper = king_;
        tickMint = 10_000_000e18;
        borrowBps = 7000;
        wrapBps = 9000;
        targetHotGusd = 1_000_000_000e18;
    }

    function setKeeper(address k) external onlyOwner {
        keeper = k;
        emit KeeperSet(k);
    }

    function setPrimaryAmo(address amo, bool fleet) external onlyOwner {
        primaryAmo = amo;
        primaryIsFleet = fleet;
        emit PrimaryAmoSet(amo, fleet);
    }

    function setParams(uint256 tickMint_, uint256 borrowBps_, uint256 wrapBps_, uint256 targetHotGusd_)
        external
        onlyOwner
    {
        tickMint = tickMint_;
        borrowBps = borrowBps_;
        wrapBps = wrapBps_;
        targetHotGusd = targetHotGusd_;
    }

    function hotGusd() public view returns (uint256) {
        return gusd.balanceOf(king);
    }

    /// @notice One autonomous print cycle. gUSD is wrap of eUSD — never free-minted.
    function execTick() external onlyKeeper nonReentrant {
        if (hotGusd() >= targetHotGusd) revert TargetHit();
        if (primaryAmo == address(0)) revert BadAmo();

        uint256 mintAmt = tickMint;
        IMintEusd(address(eusd)).mint(landing, mintAmt);
        mintedTotal += mintAmt;

        // Borrow to this bot, wrap face to king. Landing must pre-approve primaryAmo for eUSD.
        uint256 borrowed;
        if (primaryIsFleet) {
            CrownSovereignAmoFleet amo = CrownSovereignAmoFleet(primaryAmo);
            amo.supplyAmo(landing, mintAmt);
            uint256 ask = (amo.idle() * borrowBps) / 10_000;
            borrowed = amo.borrowLoan(ask, address(this));
        } else {
            (bool ok1,) = primaryAmo.call(abi.encodeWithSignature("supplyAmo(address,uint256)", landing, mintAmt));
            require(ok1, "SUPPLY");
            (bool okIdle, bytes memory idleData) = primaryAmo.staticcall(abi.encodeWithSignature("idle()"));
            require(okIdle, "IDLE");
            uint256 idleBal = abi.decode(idleData, (uint256));
            uint256 ask = (idleBal * borrowBps) / 10_000;
            (bool ok2, bytes memory borData) =
                primaryAmo.call(abi.encodeWithSignature("borrowEusd(uint256,address)", ask, address(this)));
            require(ok2, "BORROW");
            borrowed = abi.decode(borData, (uint256));
        }

        uint256 wrapped = (borrowed * wrapBps) / 10_000;
        if (wrapped > 0) {
            eusd.approve(address(gusd), wrapped);
            gusd.wrap(wrapped, king);
        }
        // leftover eUSD buffer stays on bot → king
        uint256 dust = eusd.balanceOf(address(this));
        if (dust > 0) eusd.safeTransfer(king, dust);

        ticksDone += 1;
        emit Tick(mintAmt, borrowed, wrapped, hotGusd());
    }
}
