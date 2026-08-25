// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MorphoRssOracle} from "../src/MorphoRssOracle.sol";
import {CrownZkMesh} from "../src/zk/CrownZkMesh.sol";
import {CrownElephantIntent8888} from "../src/stack/CrownElephantIntent8888.sol";

contract V4CompleteForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant BOUND = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant SETTLE = 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637;
    address constant ORACLE50 = 0x264f7AfB8f12028345B87FD5E58F2CF444EebA90;
    address constant MESH = 0x9702dd14e567BBf095D43c4Bbfe7D0ec2c79dB5a;
    address constant ELE8888 = 0x98A93dF29eFf6d131d0421C2fEfBC36D3D4693b2;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID50 = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_live_50k_oracle_and_market() public view {
        assertEq(MorphoRssOracle(ORACLE50).price(), 50_000e36);
        (address loan, address coll, address ora,, uint256 lltv) =
            IMorphoV(MORPHO).idToMarketParams(MID50);
        assertEq(loan, 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a);
        assertEq(coll, 0x7a305D07B537359cf468eAea9bb176E5308bC337);
        assertEq(ora, ORACLE50);
        assertEq(lltv, 770000000000000000);
        console2.log("oracle50k", MorphoRssOracle(ORACLE50).price());
    }

    function test_live_mesh_and_8888() public view {
        assertTrue(CrownZkMesh(MESH).isProvenHere(HOT));
        assertEq(address(CrownElephantIntent8888(ELE8888).settleGate()), SETTLE);
        console2.log("meshProven", true);
    }
}

interface IMorphoV {
    function idToMarketParams(bytes32)
        external
        view
        returns (address, address, address, address, uint256);
}
