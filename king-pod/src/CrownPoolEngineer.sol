// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IYrssVault {
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256);
}

interface IEusdMint {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

interface IBorders {
    function bordersSecure() external view returns (bool);
}

interface INPM {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

/// @title CrownPoolEngineer
/// @notice Engineer eUSD/USDC UniV3 seed from own yRSS margin. No outside beg. Loan ≠ sell RSS.
contract CrownPoolEngineer is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    address public immutable yrss;
    address public immutable eusd;
    address public immutable usdc;
    address public immutable rss;
    address public immutable npm;
    address public immutable hot;

    address public attest;
    address public agent;
    int24 public tickLower = 320000;
    int24 public tickUpper = 350000;
    uint256 public lastTokenId;
    uint256 public totalUsdcSeeded;

    mapping(address => bool) public operator;

    event AgentSet(address agent);
    event AttestSet(address attest);
    event OperatorSet(address op, bool on);
    event TicksSet(int24 lower, int24 upper);
    event SeededFromYrss(uint256 usdcIn, uint256 eusdIn, uint256 tokenId, uint128 liquidity);
    event SeededFromUsdc(uint256 usdcIn, uint256 eusdIn, uint256 tokenId, uint128 liquidity);

    error Auth();
    error Borders();
    error Bad();
    error Minter();
    error RssSold();

    modifier onlyAgentOrOp() {
        if (msg.sender != owner && msg.sender != hot && msg.sender != agent && !operator[msg.sender]) revert Auth();
        _;
    }

    constructor(
        address yrss_,
        address eusd_,
        address usdc_,
        address rss_,
        address npm_,
        address hot_,
        address attest_,
        address owner_
    ) Ownable(owner_) {
        require(yrss_ != address(0) && eusd_ != address(0) && usdc_ != address(0), "ZERO");
        require(npm_ != address(0) && hot_ != address(0), "ZERO");
        yrss = yrss_;
        eusd = eusd_;
        usdc = usdc_;
        rss = rss_;
        npm = npm_;
        hot = hot_;
        attest = attest_;
    }

    function setAgent(address a) external onlyOwner {
        agent = a;
        emit AgentSet(a);
    }

    function setAttest(address a) external onlyOwner {
        attest = a;
        emit AttestSet(a);
    }

    function setOperator(address op, bool on) external onlyOwner {
        operator[op] = on;
        emit OperatorSet(op, on);
    }

    function setTicks(int24 lower, int24 upper) external onlyOwner {
        require(lower < upper, "TICK");
        tickLower = lower;
        tickUpper = upper;
        emit TicksSet(lower, upper);
    }

    /// @notice Pull Kingdom USDC (Morpho-borrow / dealloc / desk), mint eUSD, mint Uni LP.
    /// @dev Primary path while yRSS maxWithdraw=0. USDC must be Kingdom margin — not outside beg.
    function seedFromUsdc(uint256 usdcAmt, bool requireBorders)
        external
        onlyAgentOrOp
        nonReentrant
        returns (uint256 tokenId, uint128 liq)
    {
        if (usdcAmt == 0) revert Bad();
        _gate(requireBorders);
        uint256 rssBefore = _rssHeld();
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), usdcAmt);
        (tokenId, liq) = _mintPair(usdcAmt);
        if (_rssHeld() < rssBefore) revert RssSold();
        emit SeededFromUsdc(usdcAmt, usdcAmt * 1e12, tokenId, liq);
    }

    /// @notice Withdraw USDC from own yRSS when vault has liquid idle, mint eUSD, mint Uni LP.
    function seedFromYrss(uint256 usdcAmt, bool requireBorders)
        external
        onlyAgentOrOp
        nonReentrant
        returns (uint256 tokenId, uint128 liq)
    {
        if (usdcAmt == 0) revert Bad();
        _gate(requireBorders);
        uint256 rssBefore = _rssHeld();

        uint256 shares = IYrssVault(yrss).convertToShares(usdcAmt);
        require(IERC20(yrss).transferFrom(msg.sender, address(this), shares), "YRSS");
        usdcAmt = IYrssVault(yrss).redeem(shares, address(this), address(this));
        if (usdcAmt == 0) revert Bad();

        (tokenId, liq) = _mintPair(usdcAmt);
        if (_rssHeld() < rssBefore) revert RssSold();
        emit SeededFromYrss(usdcAmt, usdcAmt * 1e12, tokenId, liq);
    }

    function _gate(bool requireBorders) internal view {
        if (requireBorders && attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
        if (!IEusdMint(eusd).isMinter(address(this))) revert Minter();
    }

    function _rssHeld() internal view returns (uint256) {
        return IERC20(rss).balanceOf(hot) + IERC20(rss).balanceOf(address(this));
    }

    function _mintPair(uint256 usdcAmt) internal returns (uint256 tokenId, uint128 liq) {
        uint256 eusdAmt = usdcAmt * 1e12;
        IEusdMint(eusd).mint(address(this), eusdAmt);
        (tokenId, liq) = _mintLp(usdcAmt, eusdAmt);
        totalUsdcSeeded += usdcAmt;
    }

    function _mintLp(uint256 usdcAmt, uint256 eusdAmt) internal returns (uint256 tokenId, uint128 liq) {
        IERC20(usdc).safeApprove(npm, usdcAmt);
        IERC20(eusd).safeApprove(npm, eusdAmt);
        INPM.MintParams memory p;
        p.token0 = usdc;
        p.token1 = eusd;
        p.fee = 500;
        p.tickLower = tickLower;
        p.tickUpper = tickUpper;
        p.amount0Desired = usdcAmt;
        p.amount1Desired = eusdAmt;
        p.recipient = hot;
        p.deadline = block.timestamp;
        (tokenId, liq,,) = INPM(npm).mint(p);
        lastTokenId = tokenId;
        _returnDust();
    }

    function _returnDust() internal {
        uint256 u = IERC20(usdc).balanceOf(address(this));
        uint256 e = IERC20(eusd).balanceOf(address(this));
        if (u > 0) IERC20(usdc).safeTransfer(hot, u);
        if (e > 0) IERC20(eusd).safeTransfer(hot, e);
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(hot, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
