// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Move 3 rebalancer - elite PA pull into RSS (or DRY_RUN).
/// @dev Reads yRSS withdraw queue + PA flowCaps + market idle.
///      IF pullable >= REQUIRED -> PublicAllocator.reallocateTo(yRSS -> RSS).
///      Env: PRIVATE_KEY, REQUIRED (USDC raw, default 0 = report only), BROADCAST=1 to fire.

interface IMetaMorphoR {
    function withdrawQueueLength() external view returns (uint256);
    function withdrawQueue(uint256) external view returns (bytes32);
}

interface IMorphoR {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128 totalSupplyAssets, uint128 totalSupplyShares, uint128 totalBorrowAssets, uint128, uint128, uint256);

    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128, uint128);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv);
}

interface IPublicAllocatorR {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
    function fee(address vault) external view returns (uint256);
    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;
}

contract KarRebalancer is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    // Target: RSS/USDC (primary PoD book)
    bytes32 constant RSS_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant RSS_ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_RSS = 770000000000000000;

    // Preferred source markets (Steakhouse-style blue-chip books on yRSS)
    bytes32 constant CBBTC_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_ID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    uint256 constant MAX_SOURCES = 8;

    function run() external {
        uint256 required = vm.envOr("REQUIRED", uint256(0));
        bool doBroadcast = vm.envOr("BROADCAST", uint256(0)) == 1;

        (uint128 rssMaxIn,) = IPublicAllocatorR(PA).flowCaps(YRSS, RSS_ID);
        console2.log("rssMaxIn", uint256(rssMaxIn));
        console2.log("required", required);

        // Collect pullable sources: prefer cbBTC/WETH, then any other queue market with idle.
        bytes32[MAX_SOURCES] memory ids;
        uint128[MAX_SOURCES] memory amts;
        uint256 n;

        n = _tryPush(ids, amts, n, CBBTC_ID, required == 0 ? type(uint128).max : uint128(required));
        n = _tryPush(ids, amts, n, WETH_ID, required == 0 ? type(uint128).max : uint128(_remaining(required, amts, n)));

        if (required > 0 && _sum(amts, n) < required) {
            uint256 len = IMetaMorphoR(YRSS).withdrawQueueLength();
            for (uint256 i; i < len && _sum(amts, n) < required; ++i) {
                bytes32 mid = IMetaMorphoR(YRSS).withdrawQueue(i);
                if (mid == RSS_ID || mid == CBBTC_ID || mid == WETH_ID) continue;
                n = _tryPush(ids, amts, n, mid, uint128(required - _sum(amts, n)));
            }
        }

        uint256 pulled = _sum(amts, n);
        console2.log("sources", n);
        console2.log("pullableTotal", pulled);

        if (required == 0) {
            console2.log("DRY: set REQUIRED=<usdc_raw> BROADCAST=1 to fire");
            return;
        }
        if (pulled < required) {
            console2.log("NOOP: idle in yRSS sources < REQUIRED (foreign market idle is not siphonable)");
            return;
        }
        if (uint256(rssMaxIn) < required) {
            console2.log("NOOP: RSS maxIn < REQUIRED");
            return;
        }

        // Sort withdrawals by market id ascending (PA invariant)
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                if (uint256(ids[j]) < uint256(ids[i])) {
                    (ids[i], ids[j]) = (ids[j], ids[i]);
                    (amts[i], amts[j]) = (amts[j], amts[i]);
                }
            }
        }

        IPublicAllocatorR.Withdrawal[] memory withdrawals = new IPublicAllocatorR.Withdrawal[](n);
        uint256 left = required;
        uint256 used;
        for (uint256 i; i < n; ++i) {
            uint128 take = amts[i];
            if (uint256(take) > left) take = uint128(left);
            if (take == 0) continue;
            (address loan, address coll, address oracle, address irm, uint256 lltv) =
                IMorphoR(MORPHO).idToMarketParams(ids[i]);
            withdrawals[used] = IPublicAllocatorR.Withdrawal({
                marketParams: IPublicAllocatorR.MarketParams({
                    loanToken: loan, collateralToken: coll, oracle: oracle, irm: irm, lltv: lltv
                }),
                amount: take
            });
            left -= take;
            used++;
            if (left == 0) break;
        }
        // shrink
        assembly {
            mstore(withdrawals, used)
        }

        IPublicAllocatorR.MarketParams memory supply = IPublicAllocatorR.MarketParams({
            loanToken: USDC, collateralToken: RSS, oracle: RSS_ORACLE, irm: IRM, lltv: LLTV_RSS
        });

        uint256 fee = IPublicAllocatorR(PA).fee(YRSS);
        console2.log("feeWei", fee);
        console2.log("willPull", required - left);

        if (!doBroadcast) {
            console2.log("DRY OK - re-run with BROADCAST=1");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        IPublicAllocatorR(PA).reallocateTo{value: fee}(YRSS, withdrawals, supply);
        vm.stopBroadcast();
        console2.log("FIRE: reallocateTo done");
    }

    function _pullable(bytes32 mid) internal view returns (uint128) {
        (uint256 shares,,) = IMorphoR(MORPHO).position(mid, YRSS);
        if (shares == 0) return 0;
        (uint128 sa, uint128 ss, uint128 ba,,,) = IMorphoR(MORPHO).market(mid);
        if (ss == 0) return 0;
        uint256 assets = shares * uint256(sa) / uint256(ss);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        (, uint128 maxOut) = IPublicAllocatorR(PA).flowCaps(YRSS, mid);
        uint256 p = assets;
        if (idle < p) p = idle;
        if (uint256(maxOut) < p) p = uint256(maxOut);
        if (p > type(uint128).max) p = type(uint128).max;
        return uint128(p);
    }

    function _tryPush(
        bytes32[MAX_SOURCES] memory ids,
        uint128[MAX_SOURCES] memory amts,
        uint256 n,
        bytes32 mid,
        uint128 want
    ) internal view returns (uint256) {
        if (n >= MAX_SOURCES || want == 0) return n;
        uint128 p = _pullable(mid);
        if (p == 0) return n;
        if (p > want) p = want;
        ids[n] = mid;
        amts[n] = p;
        console2.log("source");
        console2.logBytes32(mid);
        console2.log("amount", uint256(p));
        return n + 1;
    }

    function _sum(uint128[MAX_SOURCES] memory amts, uint256 n) internal pure returns (uint256 s) {
        for (uint256 i; i < n; ++i) s += amts[i];
    }

    function _remaining(uint256 required, uint128[MAX_SOURCES] memory amts, uint256 n) internal pure returns (uint256) {
        uint256 s = _sum(amts, n);
        return s >= required ? 0 : required - s;
    }
}
