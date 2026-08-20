// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownRssPodWrap} from "../src/peapods/CrownRssPodWrap.sol";
import {CrownFusdVault} from "../src/peapods/CrownFusdVault.sol";
import {CrownPeapodsPair} from "../src/peapods/CrownPeapodsPair.sol";
import {CrownPeapodsRssSelfLend} from "../src/peapods/CrownPeapodsRssSelfLend.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IUniV2FactoryT {
    function getPair(address, address) external view returns (address);
    function createPair(address, address) external returns (address);
}

/// @dev Fork proof: RSS/$1200 Peapods L1-L7 self-lend → 100% fUSDC util, LP collateral posted.
contract PeapodsRss1200ForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address constant FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

    uint256 constant RSS_USD = 1200;

    function test_rss1200_peapods_self_lend_834() public {
        uint256 rssTokens = 834;
        uint256 rssAmt = rssTokens * 1e18;
        uint256 usdcAmt = rssTokens * RSS_USD * 1e6;

        vm.assume(IERC20T(USDC).balanceOf(MORPHO) >= usdcAmt);

        vm.startPrank(HOT);

        CrownRssPodWrap pRss = new CrownRssPodWrap(RSS, HOT);
        CrownFusdVault vault = new CrownFusdVault(USDC, HOT);

        address lp = IUniV2FactoryT(FACTORY).getPair(address(pRss), address(vault));
        if (lp == address(0)) {
            lp = IUniV2FactoryT(FACTORY).createPair(address(pRss), address(vault));
        }

        CrownPeapodsPair pair = new CrownPeapodsPair(address(vault), lp, HOT);
        vault.setPair(address(pair));

        CrownPeapodsRssSelfLend seeder = new CrownPeapodsRssSelfLend(
            MORPHO, USDC, RSS, address(pRss), address(vault), address(pair), ROUTER, lp, HOT, HOT
        );

        IERC20T(RSS).approve(address(seeder), type(uint256).max);
        seeder.selfLend(rssAmt, usdcAmt);

        vm.stopPrank();

        console2.log("vaultCash", vault.cash());
        console2.log("vaultBorrows", vault.totalBorrows());
        console2.log("pairDebt", pair.debt(HOT));
        console2.log("pairColl", pair.collateral(HOT));

        assertGe(vault.totalBorrows(), usdcAmt - 1);
        assertEq(vault.cash(), 0);
        assertGt(pair.collateral(HOT), 0);
        assertGe(pair.debt(HOT), usdcAmt - 1);
    }
}
