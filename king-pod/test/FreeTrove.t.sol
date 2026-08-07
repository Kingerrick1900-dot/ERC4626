// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function mint(address, uint256) external;
}
interface ITrove {
    function debt() external view returns (uint256);
    function collateral() external view returns (uint256);
    function repay(uint256, uint256) external;
}

contract FreeTroveFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant TROVE = 0xC499bbD936Ba012fd77e8494a955D62e95503fFD;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_free_trove() public {
        uint256 debt = ITrove(TROVE).debt();
        uint256 coll = ITrove(TROVE).collateral();
        console2.log("debt", debt);
        console2.log("coll", coll);
        uint256 rssBefore = IERC20(RSS).balanceOf(HOT);

        vm.startPrank(HOT);
        IERC20(EUSD).mint(HOT, debt + 1e18);
        IERC20(EUSD).approve(TROVE, type(uint256).max);

        uint256[6] memory a1 = [debt, debt + 1, type(uint256).max, coll, uint256(0), debt];
        uint256[6] memory a2 = [coll, uint256(0), debt, debt, coll, type(uint256).max];
        for (uint256 i; i < 6; i++) {
            uint256 x = a1[i];
            uint256 y = a2[i];
            uint256 d0 = ITrove(TROVE).debt();
            if (d0 == 0) break;
            try ITrove(TROVE).repay(x, y) {
                console2.log("OK x", x);
                console2.log("OK y", y);
                console2.log("debt now", ITrove(TROVE).debt());
                console2.log("coll now", ITrove(TROVE).collateral());
            } catch (bytes memory err) {
                bytes4 sel;
                if (err.length >= 4) {
                    sel = bytes4(err[0]) | (bytes4(err[1]) >> 8) | (bytes4(err[2]) >> 16) | (bytes4(err[3]) >> 24);
                }
                console2.log("FAIL i", i);
                console2.logBytes32(bytes32(sel));
            }
        }
        console2.log("hot rss delta", IERC20(RSS).balanceOf(HOT) - rssBefore);
        vm.stopPrank();
    }
}
