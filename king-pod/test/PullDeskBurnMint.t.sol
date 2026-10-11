// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

interface IE {
  function balanceOf(address) external view returns (uint256);
  function burn(address,uint256) external;
  function mint(address,uint256) external;
  function approve(address,uint256) external returns (bool);
  function isMinter(address) external view returns (bool);
}
interface IR {
  function zkSupply(uint256,address) external returns (uint256,uint256);
  function totalSupplied() external view returns (uint256);
}
interface IZ { function isProven(address) external view returns (bool); }
interface IB { function bordersSecure() external view returns (bool); }

contract PullDeskBurnMint is Test {
  address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
  address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
  address constant A = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;
  address constant C = 0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B;
  address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
  address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
  address constant RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;

  function testBurnMintZk() external {
    uint256 a = IE(EUSD).balanceOf(A);
    uint256 c = IE(EUSD).balanceOf(C);
    uint256 e = IE(EUSD).balanceOf(EXIT);
    uint256 before = IR(RAIL).totalSupplied();
    console2.log("desk", a, c, e);
    console2.log("minter", IE(EUSD).isMinter(HOT));
    vm.startPrank(HOT);
    if (a > 0) IE(EUSD).burn(A, a);
    if (c > 0) IE(EUSD).burn(C, c);
    if (e > 0) IE(EUSD).burn(EXIT, e);
    uint256 got = a + c + e;
    IE(EUSD).mint(HOT, got);
    console2.log("HOT", IE(EUSD).balanceOf(HOT));
    require(IE(EUSD).balanceOf(A) == 0 && IE(EUSD).balanceOf(C) == 0, "desk not clear");
    IE(EUSD).approve(RAIL, got);
    IR(RAIL).zkSupply(got, SAFE);
    vm.stopPrank();
    console2.log("rail+", IR(RAIL).totalSupplied() - before);
    console2.log("rail", IR(RAIL).totalSupplied());
  }
}
