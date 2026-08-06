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
    function owner() external view returns (address);
}

/// @notice Base fork: free RSS → Trove → eUSD on Landing. Morpho untouched.
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

    function test_fork_mint_400k_eusd_morpho_untouched() public {
        uint256 mintAmt = 400_000e18;
        uint256 collAmt = 600e18; // buffer at $1200 / 77% LTV

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

        assertEq(trove.collateral(), collAmt);
        assertEq(trove.debt(), mintAmt);
        assertEq(IEusdT(EUSD).balanceOf(LANDING), landBefore + mintAmt);
        assertEq(IERC20T(RSS).balanceOf(HOT), freeBefore - collAmt);
        assertEq(_morphoColl(), morphoBefore, "morpho touched");

        console2.log("PASS trove mint 400k eUSD; Morpho untouched");
        console2.log("LANDING_EUSD", IEusdT(EUSD).balanceOf(LANDING));
    }
}

interface IMorphoPos {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}
