// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";

interface IE {
    function balanceOf(address) external view returns (uint256);
    function burn(address, uint256) external;
    function mint(address, uint256) external;
    function approve(address, uint256) external returns (bool);
}
interface IR {
    function zkSupply(uint256, address) external returns (uint256, uint256);
    function totalSupplied() external view returns (uint256);
}

/// @notice Extract 4C/C28/EXIT inventory via eUSD minter burn→remint, then zkSupply under Safe.
contract FireZkDeskBurnMint is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant A = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;
    address constant C = 0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "bad hot key");

        uint256 a = IE(EUSD).balanceOf(A);
        uint256 cBal = IE(EUSD).balanceOf(C);
        uint256 e = IE(EUSD).balanceOf(EXIT);
        uint256 before = IR(RAIL).totalSupplied();
        uint256 got = a + cBal + e;
        require(got > 0, "nothing");

        vm.startBroadcast(pk);
        if (a > 0) IE(EUSD).burn(A, a);
        if (cBal > 0) IE(EUSD).burn(C, cBal);
        if (e > 0) IE(EUSD).burn(EXIT, e);
        IE(EUSD).mint(HOT, got);
        IE(EUSD).approve(RAIL, got);
        IR(RAIL).zkSupply(got, SAFE);
        vm.stopBroadcast();

        console2.log("burned4C", a);
        console2.log("burnedC28", cBal);
        console2.log("burnedEXIT", e);
        console2.log("zkSupplied", got);
        console2.log("railBefore", before);
        console2.log("railAfter", IR(RAIL).totalSupplied());
        console2.log("deskA", IE(EUSD).balanceOf(A));
        console2.log("deskC", IE(EUSD).balanceOf(C));
        console2.log("deskEXIT", IE(EUSD).balanceOf(EXIT));
        console2.log("hotEusd", IE(EUSD).balanceOf(HOT));
    }
}
