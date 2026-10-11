// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
interface I { function sweep(address,address,uint256) external; }
interface IE { function balanceOf(address) external view returns (uint256); function approve(address,uint256) external returns (bool); }
interface IR { function zkSupply(uint256,address) external returns (uint256,uint256); function totalSupplied() external view returns (uint256); }
contract SimPsmSweep is Test {
  function testPsm() external {
    address HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address SAFE=0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address PSM=0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address RAIL=0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
    uint256 amt=1 ether;
    uint256 before=IR(RAIL).totalSupplied();
    vm.startPrank(HOT);
    I(PSM).sweep(EUSD, HOT, amt);
    IE(EUSD).approve(RAIL, amt);
    IR(RAIL).zkSupply(amt, SAFE);
    vm.stopPrank();
    assertEq(IR(RAIL).totalSupplied(), before+amt);
  }
}
