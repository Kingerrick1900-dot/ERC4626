// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Missing piece for Landing $700k USDC: fillable exit rails.
/// Aero RSS/USDC depth ~$0.67 — do not sell into it.
///
/// Rail A — OTC eUSD: funder posts USDC → King pays eUSD → USDC to Landing
/// Rail B — RSS desk: funder funds CrownRssUsdcDesk → King draw RSS loan → Landing
/// Rail C — PSM: funder seeds MultiPSM → King redeems Landing eUSD → USDC on Landing
///
/// King owns eUSD + MultiPSM. Landing already holds ~$700k eUSD.

interface IERC20X {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IPsmX {
    function seed(address token, uint256 amount) external;
    function usdcReserve() external view returns (uint256);
    function redeemAsset(address token, uint256 amount, address to) external;
}

interface IDeskX {
    function fund(uint256 usdcIn) external;
    function draw(uint256 rssIn, uint256 usdcOut, address to) external;
    function lender() external view returns (address);
}

contract CrownLandingUsdcFacility {
    IERC20X public immutable usdc;
    IERC20X public immutable eusd;
    IERC20X public immutable rss;
    IPsmX public immutable psm;
    address public immutable king;
    address public immutable landing;

    uint256 public otcUsdc;
    address public otcFunder;

    uint256 public lastLandingCredit;
    string public lastMode;

    event RailFunded(string rail, address indexed funder, uint256 usdcIn);
    event RailSettled(string rail, uint256 usdcToLanding, uint256 auxOut);

    modifier onlyKing() {
        require(msg.sender == king, "KING");
        _;
    }

    constructor(address usdc_, address eusd_, address rss_, address psm_, address king_, address landing_) {
        usdc = IERC20X(usdc_);
        eusd = IERC20X(eusd_);
        rss = IERC20X(rss_);
        psm = IPsmX(psm_);
        king = king_;
        landing = landing_;
    }

    // ═══════ Rail A — eUSD OTC ═══════

    function fundOtc(uint256 usdcIn) external {
        require(usdcIn > 0, "AMT");
        if (otcFunder == address(0)) otcFunder = msg.sender;
        require(msg.sender == otcFunder, "FUNDER");
        require(usdc.transferFrom(msg.sender, address(this), usdcIn), "PULL");
        otcUsdc += usdcIn;
        emit RailFunded("OTC_EUSD", msg.sender, usdcIn);
    }

    /// @dev King must hold eUSD (or pull from Landing first). Pays funder eUSD, pushes USDC to Landing.
    function settleOtcEusd(uint256 usdcOut, uint256 eusdOut) external onlyKing {
        require(usdcOut > 0 && usdcOut <= otcUsdc, "USDC");
        require(eusdOut > 0, "EUSD");
        require(eusd.transferFrom(king, otcFunder, eusdOut), "EUSD");
        otcUsdc -= usdcOut;
        require(usdc.transfer(landing, usdcOut), "PUSH");
        lastLandingCredit = usdcOut;
        lastMode = "OTC_EUSD";
        emit RailSettled("OTC_EUSD", usdcOut, eusdOut);
    }

    // ═══════ Rail B — RSS loan desk (fund here; King draw on desk — onlyKing) ═══════

    function fundDesk(address desk, uint256 usdcIn) external {
        require(usdcIn > 0, "AMT");
        require(usdc.transferFrom(msg.sender, address(this), usdcIn), "PULL");
        require(usdc.approve(desk, usdcIn), "APPR");
        IDeskX(desk).fund(usdcIn);
        emit RailFunded("RSS_DESK", msg.sender, usdcIn);
    }

    /// @dev Prefer King → desk.draw directly. This helper exists when desk.king == facility (not default).
    function drawDesk(address desk, uint256 rssIn, uint256 usdcOut) external onlyKing {
        require(rssIn > 0 && usdcOut > 0, "AMT");
        require(rss.transferFrom(king, address(this), rssIn), "RSS");
        require(rss.approve(desk, rssIn), "APPR");
        uint256 before_ = usdc.balanceOf(landing);
        IDeskX(desk).draw(rssIn, usdcOut, landing);
        uint256 credit = usdc.balanceOf(landing) - before_;
        lastLandingCredit = credit;
        lastMode = "RSS_DESK";
        emit RailSettled("RSS_DESK", credit, rssIn);
    }

    // ═══════ Rail C — MultiPSM seed + eUSD redeem (PSM.seed is onlyOwner = king) ═══════

    /// @dev Funder parks USDC on facility; King pulls + seeds PSM with own key, then redeemPsmToLanding.
    function fundPsmBuffer(uint256 usdcIn) external {
        require(usdcIn > 0, "AMT");
        require(usdc.transferFrom(msg.sender, address(this), usdcIn), "PULL");
        emit RailFunded("PSM_BUFFER", msg.sender, usdcIn);
    }

    /// @dev King pulls buffered USDC to self (then `psm.seed` in same script/tx bundle).
    function pullPsmBuffer(uint256 amt) external onlyKing {
        require(usdc.transfer(king, amt), "PUSH");
    }

    /// @dev King has seeded PSM; pull eUSD and redeem USDC to Landing.
    function redeemPsmToLanding(uint256 eusdAmount) external onlyKing {
        require(eusdAmount > 0, "AMT");
        require(eusd.transferFrom(king, address(this), eusdAmount), "EUSD");
        require(eusd.approve(address(psm), eusdAmount), "APPR");
        uint256 before_ = usdc.balanceOf(landing);
        psm.redeemAsset(address(usdc), eusdAmount, landing);
        uint256 credit = usdc.balanceOf(landing) - before_;
        require(credit > 0, "NO_USDC");
        lastLandingCredit = credit;
        lastMode = "PSM_REDEEM";
        emit RailSettled("PSM", credit, eusdAmount);
    }

    function rescue(address token, uint256 amt, address to) external onlyKing {
        require(IERC20X(token).transfer(to, amt), "X");
    }
}
