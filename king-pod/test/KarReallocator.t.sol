// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownKarReallocator} from "../src/CrownKarReallocator.sol";
import {IKarPublicAllocator} from "../src/interfaces/IKarPublicAllocator.sol";

contract MockMorphoR {
    mapping(bytes32 => uint128) public supply;
    mapping(bytes32 => uint128) public borrow;

    function set(bytes32 id, uint128 s, uint128 b) external {
        supply[id] = s;
        borrow[id] = b;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128)
    {
        return (supply[id], 0, borrow[id], 0, 0, 0);
    }
}

contract MockPAR {
    uint256 public calls;

    function fee(address) external pure returns (uint256) {
        return 0;
    }

    function reallocateTo(
        address,
        IKarPublicAllocator.Withdrawal[] calldata,
        IKarPublicAllocator.MarketParams calldata
    ) external payable {
        ++calls;
    }
}

contract KarReallocatorTest is Test {
    MockMorphoR morpho;
    MockPAR pa;
    CrownKarReallocator re;
    address hot = address(0xBEEF);

    function setUp() public {
        morpho = new MockMorphoR();
        pa = new MockPAR();
        re = new CrownKarReallocator(address(pa), address(morpho), hot, address(this));
    }

    function test_utilAndIdle() public {
        bytes32 id = keccak256("m");
        morpho.set(id, 100e6, 96e6);
        assertEq(re.marketIdle(id), 4e6);
        assertEq(re.marketUtilBps(id), 9600);
    }

    function test_killswitchBlocks() public {
        IKarPublicAllocator.MarketParams memory toMp = IKarPublicAllocator.MarketParams({
            loanToken: address(1),
            collateralToken: address(2),
            oracle: address(3),
            irm: address(4),
            lltv: 5
        });
        bytes32 toId = keccak256(abi.encode(toMp));
        re.setVault(address(0x1234), toId);
        re.setArmed(true);
        re.setKillswitch(true);
        morpho.set(toId, 100e6, 96e6);
        re.setThresholds(0, 9500);

        IKarPublicAllocator.Withdrawal[] memory w = new IKarPublicAllocator.Withdrawal[](0);
        vm.prank(hot);
        vm.expectRevert(CrownKarReallocator.Killed.selector);
        re.fireReallocate(w, toMp);
    }

    function test_banBlocks() public {
        IKarPublicAllocator.MarketParams memory fromMp = IKarPublicAllocator.MarketParams({
            loanToken: address(0xA),
            collateralToken: address(0xB),
            oracle: address(0xC),
            irm: address(0xD),
            lltv: 1
        });
        IKarPublicAllocator.MarketParams memory toMp = IKarPublicAllocator.MarketParams({
            loanToken: address(0x1),
            collateralToken: address(0x2),
            oracle: address(0x3),
            irm: address(0x4),
            lltv: 2
        });
        bytes32 toId = keccak256(abi.encode(toMp));
        bytes32 fromId = keccak256(abi.encode(fromMp));
        re.setVault(address(0x1234), toId);
        re.setArmed(true);
        re.setKillswitch(false);
        re.setThresholds(0, 0);
        morpho.set(toId, 100e6, 100e6);
        morpho.set(fromId, 50e6, 0);
        re.banMarket(fromId, true);

        IKarPublicAllocator.Withdrawal[] memory w = new IKarPublicAllocator.Withdrawal[](1);
        w[0] = IKarPublicAllocator.Withdrawal({marketParams: fromMp, amount: 1e6});
        vm.prank(hot);
        vm.expectRevert(CrownKarReallocator.Banned.selector);
        re.fireReallocate(w, toMp);
    }

    function test_fireOk() public {
        IKarPublicAllocator.MarketParams memory fromMp = IKarPublicAllocator.MarketParams({
            loanToken: address(0xA),
            collateralToken: address(0),
            oracle: address(0),
            irm: address(0),
            lltv: 0
        });
        IKarPublicAllocator.MarketParams memory toMp = IKarPublicAllocator.MarketParams({
            loanToken: address(0x11),
            collateralToken: address(0x22),
            oracle: address(0x33),
            irm: address(0x44),
            lltv: 86e16
        });
        bytes32 toId = keccak256(abi.encode(toMp));
        bytes32 fromId = keccak256(abi.encode(fromMp));
        re.setVault(address(0x1234), toId);
        re.setArmed(true);
        re.setThresholds(1e6, 9500);
        morpho.set(toId, 100e6, 96e6);
        morpho.set(fromId, 50e6, 0);
        re.setRiskScore(fromId, 1000);

        IKarPublicAllocator.Withdrawal[] memory w = new IKarPublicAllocator.Withdrawal[](1);
        w[0] = IKarPublicAllocator.Withdrawal({marketParams: fromMp, amount: 10e6});
        vm.prank(hot);
        re.fireReallocate(w, toMp);
        assertEq(re.fireCount(), 1);
        assertEq(re.totalPulled(), 10e6);
        assertEq(pa.calls(), 1);
    }
}
