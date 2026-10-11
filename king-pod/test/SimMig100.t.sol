// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
interface IG { function unwrap(uint256,address) external returns (uint256); function balanceOf(address) external view returns (uint256); }
interface IE { function approve(address,uint256) external returns (bool); function balanceOf(address) external view returns (uint256); }
interface IR { function zkSupply(uint256,address) external returns (uint256,uint256); function totalSupplied() external view returns (uint256); }
contract SimMig100 is Test {
  function testMig() external {
    address HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address GUSD=0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address RAIL=0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
    address SAFE=0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    uint256 AMT=100_000_000 ether;
    uint256 beforeRail=IR(RAIL).totalSupplied();
    vm.startPrank(HOT);
    IG(GUSD).unwrap(AMT, HOT);
    IE(EUSD).approve(RAIL, AMT);
    IR(RAIL).zkSupply(AMT, SAFE);
    vm.stopPrank();
    assertEq(IE(EUSD).balanceOf(HOT), 0);
    assertEq(IR(RAIL).totalSupplied(), beforeRail+AMT);
  }
}
