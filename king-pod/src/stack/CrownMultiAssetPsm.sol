// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IAggregatorV3Lite {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function latestAnswer() external view returns (int256);
}

interface IEusdBurnLite {
    function burn(address from, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

interface IWETH9 {
    function withdraw(uint256) external;
    function deposit() external payable;
}

/// @notice Multi-asset PSM: eUSD ↔ USDC / USDT / DAI / ETH(WETH) / EURC via Chainlink feeds.
/// @dev Keeps `redeemUsdc` + `usdc()` so existing ERC-7540 vault bytecode can wrap this PSM unchanged.
///      Additional assets via `redeemAsset` / `redeemEth`. Does not modify 7540/7683 contracts.
contract CrownMultiAssetPsm is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant MAX_STALE = 1 days;

    IERC20 public immutable eusd;
    /// @notice Canonical USDC — used by `redeemUsdc` / `usdc()` for ERC-7540 vault compatibility.
    address public immutable usdcToken;
    address public immutable landing;
    address public immutable weth; // canonical ETH asset (WETH)

    struct AssetConfig {
        address token;
        address feed; // Chainlink AggregatorV3 / capped feed
        uint8 tokenDecimals;
        bool enabled;
        bool useLatestAnswer; // true for feeds that revert on latestRoundData (e.g. capped EURC)
    }

    mapping(address => AssetConfig) public assets;
    address[] public assetList;

    event AssetListed(address indexed token, address feed, uint8 decimals, bool useLatestAnswer);
    event AssetEnabled(address indexed token, bool enabled);
    event Seeded(address indexed token, uint256 amt);
    event Redeemed(address indexed token, address indexed to, uint256 eusdIn, uint256 outAmt);
    event Swept(address indexed token, address indexed to, uint256 amt);

    error BadAmt();
    error Dry();
    error NotListed();
    error Disabled();
    error Stale();
    error BadFeed();

    constructor(address eusd_, address usdc_, address landing_, address weth_, address owner_) Ownable(owner_) {
        require(
            eusd_ != address(0) && usdc_ != address(0) && landing_ != address(0) && weth_ != address(0), "ZERO"
        );
        eusd = IERC20(eusd_);
        usdcToken = usdc_;
        landing = landing_;
        weth = weth_;
    }

    // ─── listing ───────────────────────────────────────────────────────────

    function listAsset(address token, address feed, uint8 tokenDecimals, bool useLatestAnswer)
        external
        onlyOwner
    {
        require(token != address(0) && feed != address(0), "ZERO");
        if (!assets[token].enabled && assets[token].token == address(0)) {
            assetList.push(token);
        }
        assets[token] = AssetConfig({
            token: token,
            feed: feed,
            tokenDecimals: tokenDecimals,
            enabled: true,
            useLatestAnswer: useLatestAnswer
        });
        emit AssetListed(token, feed, tokenDecimals, useLatestAnswer);
    }

    function setAssetEnabled(address token, bool enabled) external onlyOwner {
        if (assets[token].token == address(0)) revert NotListed();
        assets[token].enabled = enabled;
        emit AssetEnabled(token, enabled);
    }

    function assetCount() external view returns (uint256) {
        return assetList.length;
    }

    // ─── seed / sweep ──────────────────────────────────────────────────────

    function seed(address token, uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        if (assets[token].token == address(0)) revert NotListed();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);
        emit Seeded(token, amt);
    }

    function seedUsdc(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        if (assets[usdcToken].token == address(0)) revert NotListed();
        IERC20(usdcToken).safeTransferFrom(msg.sender, address(this), amt);
        emit Seeded(usdcToken, amt);
    }

    function sweep(address token, address to, uint256 amt) external onlyOwner nonReentrant {
        if (to == address(0)) to = landing;
        IERC20(token).safeTransfer(to, amt);
        emit Swept(token, to, amt);
    }

    // ─── views (7540-compatible surface) ───────────────────────────────────

    function usdc() external view returns (address) {
        return usdcToken;
    }

    function usdcReserve() external view returns (uint256) {
        return IERC20(usdcToken).balanceOf(address(this));
    }

    /// @dev Optional fillers for ICrownGoldParityPsm-shaped readers.
    function kxau() external pure returns (address) {
        return address(0);
    }

    function oracle() external pure returns (address) {
        return address(0);
    }

    function reserve(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function quoteAsset(address token, uint256 eusdAmt) external view returns (uint256 outAmt) {
        return _quote(token, eusdAmt);
    }

    // ─── redeem ────────────────────────────────────────────────────────────

    /// @notice 7540-compatible USDC redeem — same signature as Scroll Gold Parity PSM.
    function redeemUsdc(uint256 eusdAmt, address to) external nonReentrant returns (uint256 usdcOut) {
        usdcOut = _redeem(usdcToken, eusdAmt, to);
    }

    /// @notice Redeem eUSD for any listed asset (USDT, DAI, WETH, EURC, USDC).
    function redeemAsset(address token, uint256 eusdAmt, address to) external nonReentrant returns (uint256 outAmt) {
        outAmt = _redeem(token, eusdAmt, to);
    }

    /// @notice Native ETH redeem — unwraps WETH reserve (or uses native balance) to `to`.
    function redeemEth(uint256 eusdAmt, address to) external nonReentrant returns (uint256 ethOut) {
        if (to == address(0)) to = msg.sender;
        ethOut = _quote(weth, eusdAmt);
        if (ethOut == 0) revert BadAmt();
        if (address(this).balance < ethOut && IERC20(weth).balanceOf(address(this)) < ethOut) revert Dry();

        _pullAndBurn(eusdAmt);

        if (address(this).balance >= ethOut) {
            (bool ok,) = to.call{value: ethOut}("");
            require(ok, "ETH");
        } else {
            IWETH9(weth).withdraw(ethOut);
            (bool ok,) = to.call{value: ethOut}("");
            require(ok, "ETH2");
        }
        emit Redeemed(weth, to, eusdAmt, ethOut);
    }

    receive() external payable {}

    // ─── internal ──────────────────────────────────────────────────────────

    function _redeem(address token, uint256 eusdAmt, address to) internal returns (uint256 outAmt) {
        AssetConfig memory cfg = assets[token];
        if (cfg.token == address(0)) revert NotListed();
        if (!cfg.enabled) revert Disabled();
        if (eusdAmt == 0) revert BadAmt();
        if (to == address(0)) to = msg.sender;

        outAmt = _quote(token, eusdAmt);
        if (outAmt == 0) revert BadAmt();
        if (IERC20(token).balanceOf(address(this)) < outAmt) revert Dry();

        _pullAndBurn(eusdAmt);
        IERC20(token).safeTransfer(to, outAmt);
        emit Redeemed(token, to, eusdAmt, outAmt);
    }

    function _quote(address token, uint256 eusdAmt) internal view returns (uint256 outAmt) {
        AssetConfig memory cfg = assets[token];
        if (cfg.token == address(0) || !cfg.enabled) return 0;
        uint256 px = _priceUsd8(cfg); // USD per 1 token, 8dp
        if (px == 0) return 0;
        // eUSD 18dp at $1 → usd8 = eusdAmt / 1e10
        uint256 usd8 = eusdAmt / 1e10;
        // out = usd8 * 10^tokenDecimals / px
        outAmt = (usd8 * (10 ** uint256(cfg.tokenDecimals))) / px;
    }

    function _priceUsd8(AssetConfig memory cfg) internal view returns (uint256) {
        int256 answer;
        if (cfg.useLatestAnswer) {
            // Capped EURC adapter: latestRoundData reverts; latestAnswer() is the live path.
            answer = IAggregatorV3Lite(cfg.feed).latestAnswer();
        } else {
            uint256 updatedAt;
            (, answer,, updatedAt,) = IAggregatorV3Lite(cfg.feed).latestRoundData();
            if (block.timestamp > updatedAt + MAX_STALE) revert Stale();
        }
        if (answer <= 0) revert BadFeed();
        uint8 feedDec = IAggregatorV3Lite(cfg.feed).decimals();
        uint256 raw = uint256(answer);
        if (feedDec == 8) return raw;
        if (feedDec > 8) return raw / (10 ** uint256(feedDec - 8));
        return raw * (10 ** uint256(8 - feedDec));
    }

    function _pullAndBurn(uint256 eusdAmt) internal {
        eusd.safeTransferFrom(msg.sender, address(this), eusdAmt);
        if (IEusdBurnLite(address(eusd)).isMinter(address(this))) {
            IEusdBurnLite(address(eusd)).burn(address(this), eusdAmt);
        }
    }
}
