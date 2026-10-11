// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

interface IMorphoR {
  struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
  function isAuthorized(address,address) external view returns (bool);
  function withdraw(MarketParams memory,uint256,uint256,address,address) external returns (uint256,uint256);
  function idToMarketParams(bytes32) external view returns (address,address,address,address,uint256);
  function position(bytes32,address) external view returns (uint256,uint128,uint128);
}
interface IZkRail { function zkSupply(uint256,address) external returns (uint256,uint256); function totalSupplied() external view returns (uint256); }
interface IERC20R { function approve(address,uint256) external returns (bool); function balanceOf(address) external view returns (uint256); }

contract SimMorphoReseat is Test {
  address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
  address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
  address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
  address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
  address constant ZK_RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
  bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;

  function testReseat() external {
    require(IMorphoR(MORPHO).isAuthorized(SAFE, HOT), "auth");
    (address loan, address coll, address oracle, address irm, uint256 lltv) = IMorphoR(MORPHO).idToMarketParams(EUSD_RSS);
    (uint256 shares,,) = IMorphoR(MORPHO).position(EUSD_RSS, SAFE);
    uint256 before = IZkRail(ZK_RAIL).totalSupplied();
    console2.log("shares", shares);
    console2.log("railBefore", before);
    vm.startPrank(HOT);
    IMorphoR(MORPHO).withdraw(IMorphoR.MarketParams(loan,coll,oracle,irm,lltv), 0, shares, SAFE, HOT);
    uint256 bal = IERC20R(EUSD).balanceOf(HOT);
    console2.log("withdrawn", bal);
    IERC20R(EUSD).approve(ZK_RAIL, bal);
    IZkRail(ZK_RAIL).zkSupply(bal, SAFE);
    vm.stopPrank();
    uint256 after_ = IZkRail(ZK_RAIL).totalSupplied();
    (uint256 sh,,) = IMorphoR(MORPHO).position(EUSD_RSS, SAFE);
    console2.log("railAfter", after_);
    console2.log("safeShares", sh);
    console2.log("hot", IERC20R(EUSD).balanceOf(HOT));
    require(bal > 1_000_000 ether, "too small");
    require(after_ == before + bal, "rail math");
    require(sh > 0 && IERC20R(EUSD).balanceOf(HOT) == 0, "reseated");
  }
}
