// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoEusd {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IEusdMint {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

/// @title CrownFakeIdleEusd
/// @notice Morpho-VISIBLE idle without Circle USDC: mint/supply kingdom eUSD unmatched.
/// @dev This is the "fake idle" others use — protocol stable as Morpho loan token, not gasPark USDC.
///      Market 0x6075ba26… already has ~$43M eUSD idle. This engineers more and keeps it unlatched.
contract CrownFakeIdleEusd is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant ASK = 2_000_000e18;

    IMorphoEusd public immutable morpho;
    IERC20 public immutable eusd;
    address public immutable king;

    IMorphoEusd.MarketParams public mp;
    bytes32 public marketId;
    bool public armed = true;
    bool public mintEnabled;

    uint256 public totalEngineered;
    uint256 public lastEngineer;

    event MarketSet(bytes32 indexed id);
    event Armed(bool on);
    event MintEnabled(bool on);
    event FakeIdleEngineered(uint256 supplied, uint256 idleAfter, bool minted);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error NoBorrow();
    error BorrowGrew();
    error NotMinter();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(address morpho_, address eusd_, address king_, address owner_) Ownable(owner_) {
        morpho = IMorphoEusd(morpho_);
        eusd = IERC20(eusd_);
        king = king_;
        eusd.safeApprove(morpho_, type(uint256).max);
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setMintEnabled(bool on) external onlyOwner {
        mintEnabled = on;
        emit MintEnabled(on);
    }

    function setMarket(address coll, address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (coll == address(0) || oracle == address(0) || irm == address(0) || id == bytes32(0)) revert BadAmt();
        mp = IMorphoEusd.MarketParams(address(eusd), coll, oracle, irm, lltv);
        marketId = id;
        emit MarketSet(id);
    }

    function idle() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function utilBps() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        if (s == 0) return 0;
        return (uint256(b) * 10_000) / uint256(s);
    }

    /// @notice Engineer Morpho-visible eUSD idle. Optionally mint eUSD first (kingdom fake depth).
    /// @param amt 0 = ASK ($2M). mintFirst=true requires mintEnabled + king isMinter.
    function engineerFakeIdle(uint256 amt, bool mintFirst) external onlyKing nonReentrant returns (uint256 supplied) {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0)) revert NoMarket();
        if (amt == 0) amt = ASK;

        (, uint128 borBefore,) = morpho.position(marketId, king);

        bool minted;
        if (mintFirst) {
            if (!mintEnabled) revert NotMinter();
            if (!IEusdMint(address(eusd)).isMinter(address(this)) && !IEusdMint(address(eusd)).isMinter(king)) {
                revert NotMinter();
            }
            // Prefer contract minter; else king must have minted to this contract already
            if (IEusdMint(address(eusd)).isMinter(address(this))) {
                IEusdMint(address(eusd)).mint(address(this), amt);
                minted = true;
            } else {
                // Pull from king after king minted to self
                eusd.safeTransferFrom(msg.sender, address(this), amt);
            }
        } else {
            uint256 bal = eusd.balanceOf(address(this));
            if (bal < amt) eusd.safeTransferFrom(msg.sender, address(this), amt - bal);
        }

        uint256 idleBefore = idle();
        morpho.supply(mp, amt, 0, address(this), "");
        supplied = amt;

        (, uint128 borAfter,) = morpho.position(marketId, king);
        if (borAfter > borBefore) revert BorrowGrew();
        uint256 idleAfter = idle();
        if (idleAfter < idleBefore + amt - 1) revert IdleMiss();

        totalEngineered += amt;
        lastEngineer = amt;
        emit FakeIdleEngineered(amt, idleAfter, minted);
    }

    function borrow(uint256) external pure {
        revert NoBorrow();
    }

    function gasPark(uint256, uint256) external pure {
        revert NoBorrow();
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
