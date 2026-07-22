// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGatePcv {
    function isProven(address subject) external view returns (bool);
}

interface IMorphoPcv {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
}

interface ILbpPcv {
    function seed(uint256 rssAmt, uint256 usdcAmt, uint64 durationSec) external;
}

/// @notice Protocol Controlled Value — King commands liquidity; does not borrow it.
/// @dev Holds RSS PCV. Seeds LBP + Morpho book presence. Floor pause. ZK optional gate.
///      Vault V2 / yRSS curator seats remain King hot — this controller is the PCV purse.
contract CrownPcvController is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant FLOOR_RSS = 100_000 ether; // pause outbound if below

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    IZkGatePcv public immutable gate;
    IMorphoPcv public immutable morpho;
    address public immutable landing;
    address public immutable king;
    address public immutable oracle;
    address public immutable irm;

    address public lbp;
    address public otcEthRail;
    address public multiStableRail;
    address public vaultV2;
    bool public paused;
    bool public requireZk = true;

    uint256 public pcvRss; // accounting of RSS held here

    event PcvDeposited(uint256 amt);
    event LbpSeeded(uint256 rssAmt, uint256 usdcAmt, uint64 duration);
    event MorphoBookPosted(uint256 rssColl);
    event RailsSet(address lbp, address otc, address multi, address vaultV2);
    event Paused(bool paused);

    error BadAmt();
    error PausedErr();
    error BelowFloor();
    error NotProven();
    error NoLbp();

    modifier whenOpen() {
        if (paused) revert PausedErr();
        _;
    }

    constructor(
        address rss_,
        address usdc_,
        address gate_,
        address morpho_,
        address landing_,
        address king_,
        address oracle_,
        address irm_,
        address owner_
    ) Ownable(owner_) {
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        gate = IZkGatePcv(gate_);
        morpho = IMorphoPcv(morpho_);
        landing = landing_;
        king = king_;
        oracle = oracle_;
        irm = irm_;
    }

    function setRails(address lbp_, address otc_, address multi_, address vaultV2_) external onlyOwner {
        lbp = lbp_;
        otcEthRail = otc_;
        multiStableRail = multi_;
        vaultV2 = vaultV2_;
        emit RailsSet(lbp_, otc_, multi_, vaultV2_);
    }

    function setRequireZk(bool v) external onlyOwner {
        requireZk = v;
    }

    function setPaused(bool v) external onlyOwner {
        paused = v;
        emit Paused(v);
    }

    function _zk() internal view {
        if (requireZk && !gate.isProven(king)) revert NotProven();
    }

    /// @notice Deposit RSS as PCV (protocol-owned — not a loan).
    function depositPcv(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), amt);
        pcvRss += amt;
        emit PcvDeposited(amt);
    }

    /// @notice Seed LBP from PCV. Enforces floor after seed.
    function seedLbpFromPcv(uint256 rssAmt, uint256 usdcAmt, uint64 durationSec)
        external
        onlyOwner
        nonReentrant
        whenOpen
    {
        _zk();
        if (lbp == address(0)) revert NoLbp();
        if (rssAmt == 0 || rssAmt > pcvRss) revert BadAmt();
        if (pcvRss - rssAmt < FLOOR_RSS) revert BelowFloor();

        pcvRss -= rssAmt;
        rss.safeApprove(lbp, rssAmt);
        if (usdcAmt > 0) {
            usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
            usdc.safeApprove(lbp, usdcAmt);
        }
        ILbpPcv(lbp).seed(rssAmt, usdcAmt, durationSec);
        emit LbpSeeded(rssAmt, usdcAmt, durationSec);
    }

    /// @notice Post RSS on Morpho as protocol book presence (no borrow — command, don't debt).
    function postMorphoBook(uint256 rssColl) external onlyOwner nonReentrant whenOpen {
        _zk();
        if (rssColl == 0 || rssColl > pcvRss) revert BadAmt();
        if (pcvRss - rssColl < FLOOR_RSS) revert BelowFloor();

        pcvRss -= rssColl;
        // Live RSS/USDC Morpho market LLTV = 77% (immutable)
        IMorphoPcv.MarketParams memory mp = IMorphoPcv.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(rss),
            oracle: oracle,
            irm: irm,
            lltv: 770000000000000000
        });
        rss.safeApprove(address(morpho), rssColl);
        morpho.supplyCollateral(mp, rssColl, address(this), "");
        emit MorphoBookPosted(rssColl);
    }

    function pcvBalance() external view returns (uint256) {
        return rss.balanceOf(address(this));
    }

    function rescue(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(landing, amt);
    }
}
