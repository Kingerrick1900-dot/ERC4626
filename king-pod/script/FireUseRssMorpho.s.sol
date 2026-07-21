// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20R {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoR {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
}

/// @notice USE THE RSS — post tokens Morpho marks @ $1, borrow all idle USDC to Hot. No flash. No cbBTC detour.
/// @dev KING_OK=1 KING_GO=1 FIRE_RSS=1
///      POST_RSS default 1M. POST_ALL=1 posts entire hot RSS across RSS77 + RSS91.
///      MIN_BORROW default 1 wei — borrows whatever idle exists (even ~$1).
contract FireUseRssMorpho is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant RSS91 = 0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126;

    uint256 constant SOFT_LTV_BPS = 7000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        bool doFire = vm.envOr("FIRE_RSS", uint256(0)) == 1;

        address receiver = vm.envOr("RECEIVER", HOT);
        require(receiver == HOT || receiver == LANDING, "RECEIVER");

        bool postAll = vm.envOr("POST_ALL", uint256(0)) == 1;
        bool use91 = vm.envOr("USE_RSS91", uint256(1)) == 1;
        uint256 postRss = vm.envOr("POST_RSS", uint256(1_000_000 ether));
        uint256 minBorrow = vm.envOr("MIN_BORROW", uint256(1));

        uint256 rssBal = IERC20R(RSS).balanceOf(HOT);
        if (postAll) postRss = rssBal;
        require(postRss > 0 && rssBal >= postRss, "NEED RSS");

        uint256 rss77Amt = postRss;
        uint256 rss91Amt;
        if (use91 && postAll) {
            rss77Amt = (postRss * 70) / 100;
            rss91Amt = postRss - rss77Amt;
        } else if (use91 && !postAll) {
            rss91Amt = postRss / 2;
            rss77Amt = postRss - rss91Amt;
        }

        console2.log("=== USE RSS ON MORPHO ===");
        console2.log("rssHot", rssBal);
        console2.log("postRss77", rss77Amt);
        console2.log("postRss91", rss91Amt);
        console2.log("receiver", receiver);

        _logMarket(RSS77, rss77Amt);
        if (rss91Amt > 0) _logMarket(RSS91, rss91Amt);

        if (!doFire) {
            console2.log("DRY set FIRE_RSS=1 to post + borrow");
            return;
        }

        uint256 recvBefore = IERC20R(USDC).balanceOf(receiver);
        uint256 totalBorrow;

        vm.startBroadcast(pk);
        if (rss77Amt > 0) totalBorrow += _postAndBorrow(RSS77, rss77Amt, receiver, minBorrow);
        if (rss91Amt > 0) totalBorrow += _postAndBorrow(RSS91, rss91Amt, receiver, minBorrow);
        vm.stopBroadcast();

        uint256 gain = IERC20R(USDC).balanceOf(receiver) - recvBefore;
        console2.log("=== RSS MORPHO RESULT ===");
        console2.log("borrowedUsdc", totalBorrow);
        console2.log("walletGain", gain);
        console2.log("RSS_POSTED", uint256(1));
        if (totalBorrow > 0) require(gain >= totalBorrow, "ACCESS FAIL");
    }

    function _logMarket(bytes32 mid, uint256 postRss) internal view {
        (uint128 supply,, uint128 borrowed,,,) = IMorphoR(MORPHO).market(mid);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;
        (, , uint128 collNow) = IMorphoR(MORPHO).position(mid, HOT);
        uint256 headroom = ((uint256(collNow) + postRss) * SOFT_LTV_BPS / 10_000) * 1e6 / 1e18;
        uint256 maxNow = idle < headroom ? idle : headroom;
        console2.log("market", uint256(mid));
        console2.log("  poolIdle", idle);
        console2.log("  yourCapacity", headroom);
        console2.log("  borrowNow", maxNow);
    }

    function _postAndBorrow(bytes32 mid, uint256 postRss, address receiver, uint256 minBorrow)
        internal
        returns (uint256 borrowed)
    {
        IMorphoR.MarketParams memory mp = IMorphoR(MORPHO).idToMarketParams(mid);
        require(mp.collateralToken == RSS && mp.loanToken == USDC, "market");

        (uint128 supply,, uint128 borrowedBefore,,,) = IMorphoR(MORPHO).market(mid);
        uint256 idle = uint256(supply) > uint256(borrowedBefore) ? uint256(supply) - uint256(borrowedBefore) : 0;
        (, , uint128 collNow) = IMorphoR(MORPHO).position(mid, HOT);
        uint256 headroom = ((uint256(collNow) + postRss) * SOFT_LTV_BPS / 10_000) * 1e6 / 1e18;

        IERC20R(RSS).approve(MORPHO, postRss);
        IMorphoR(MORPHO).supplyCollateral(mp, postRss, HOT, "");

        borrowed = idle;
        if (borrowed > headroom) borrowed = headroom;
        if (borrowed >= minBorrow) {
            IMorphoR(MORPHO).borrow(mp, borrowed, 0, HOT, receiver);
        }
    }
}
