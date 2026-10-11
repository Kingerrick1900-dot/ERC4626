// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
interface ISweep { function sweep(address,uint256) external; function owner() external view returns (address); }
interface IE { function balanceOf(address) external view returns (uint256); function approve(address,uint256) external returns (bool); }
interface IR { function zkSupply(uint256,address) external returns (uint256,uint256); function totalSupplied() external view returns (uint256); }
contract SimAbSweep is Test {
  function testSweep() external {
    address HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address SAFE=0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address AB=0xAb21623705493538e7E86AAcC79C0297427dc3B2;
    address EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address RAIL=0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
    uint256 amt=100_000_000 ether;
    uint256 before=IR(RAIL).totalSupplied();
    vm.startPrank(HOT);
    ISweep(AB).sweep(EUSD, amt);
    uint256 hotBal=IE(EUSD).balanceOf(HOT);
    console2.log("HOT_EUSD", hotBal);
    require(hotBal>=amt, "no eusd");
    IE(EUSD).approve(RAIL, amt);
    IR(RAIL).zkSupply(amt, SAFE);
    vm.stopPrank();
    assertEq(IR(RAIL).totalSupplied(), before+amt);
  }
}
