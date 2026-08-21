// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownRssTrove} from "../src/CrownRssTrove.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IEusdT {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoPos {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IOracleT {
    function price() external view returns (uint256);
}

/// @notice Base fork: free RSS → Trove → eUSD. Morpho $200M signal untouched.
contract RssTroveMintFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant M1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function _morphoColl() internal view returns (uint256 coll) {
        (,, coll) = IMorphoPos(MORPHO).position(M1200, HOT);
    }

    function _collFor(uint256 mintAmt, uint256 ltv) internal view returns (uint256) {
        uint256 px = IOracleT(ORACLE).price();
        uint256 collAmt = (mintAmt * 1e36) / (px * 1e12);
        collAmt = (collAmt * 1e18) / ltv;
        collAmt = (collAmt * 120) / 100;
        return ((collAmt + 1e18 - 1) / 1e18) * 1e18;
    }

    function test_fork_mint_400k_eusd_morpho_untouched() public {
        uint256 mintAmt = 400_000e18;
        uint256 collAmt = _collFor(mintAmt, 0.77e18);

        uint256 morphoBefore = _morphoColl();
        uint256 freeBefore = IERC20T(RSS).balanceOf(HOT);
        uint256 landBefore = IEusdT(EUSD).balanceOf(LANDING);
        require(freeBefore >= collAmt, "need free RSS");

        vm.startPrank(HOT);
        CrownRssTrove trove = new CrownRssTrove(
            RSS, EUSD, ORACLE, HOT, LANDING, 0.77e18, 0.05e18, 1_000_000e18
        );
        IEusdT(EUSD).setMinter(address(trove), true);
        IERC20T(RSS).approve(address(trove), collAmt);
        trove.open(collAmt, mintAmt, LANDING);
        vm.stopPrank();

        assertEq(trove.debt(), mintAmt);
        assertEq(IEusdT(EUSD).balanceOf(LANDING), landBefore + mintAmt);
        assertEq(_morphoColl(), morphoBefore, "morpho touched");
        console2.log("PASS 400k; Morpho untouched");
    }

    function test_fork_size_100m_fits_free_rss() public {
        uint256 mintAmt = 100_000_000e18;
        uint256 collAmt = _collFor(mintAmt, 0.77e18);
        uint256 free = IERC20T(RSS).balanceOf(HOT);
        console2.log("collRss100m", collAmt);
        console2.log("freeRss", free);
        assertGe(free, collAmt, "100M must fit free RSS");
        // Morpho signal coll stays reserved conceptually — free already excludes posted
        assertGe(free - collAmt, 1_000_000 ether, "keep >=1M liquid after mint coll");
    }

    function test_fork_mint_100m_morpho_untouched() public {
        uint256 mintAmt = 100_000_000e18;
        uint256 collAmt = _collFor(mintAmt, 0.77e18);
        uint256 morphoBefore = _morphoColl();
        uint256 landBefore = IEusdT(EUSD).balanceOf(LANDING);

        vm.startPrank(HOT);
        CrownRssTrove trove = new CrownRssTrove(
            RSS, EUSD, ORACLE, HOT, LANDING, 0.77e18, 0.05e18, 100_000_000e18
        );
        IEusdT(EUSD).setMinter(address(trove), true);
        IERC20T(RSS).approve(address(trove), collAmt);
        trove.open(collAmt, mintAmt, LANDING);
        vm.stopPrank();

        assertEq(trove.debt(), mintAmt);
        assertEq(IEusdT(EUSD).balanceOf(LANDING), landBefore + mintAmt);
        assertEq(_morphoColl(), morphoBefore, "morpho signal touched");
        console2.log("PASS 100M mint; Morpho untouched");
    }
}
