// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

interface IMorpho {
  struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
  function idToMarketParams(bytes32) external view returns (address,address,address,address,uint256);
  function position(bytes32,address) external view returns (uint256,uint128,uint128);
  function withdraw(MarketParams memory,uint256,uint256,address,address) external returns (uint256,uint256);
  function repay(MarketParams memory,uint256,uint256,address,bytes calldata) external returns (uint256,uint256);
  function isAuthorized(address,address) external view returns (bool);
}
interface IERC20 {
  function balanceOf(address) external view returns (uint256);
  function approve(address,uint256) external returns (bool);
}
interface IGusd {
  function wrap(uint256,address) external returns (uint256);
  function balanceOf(address) external view returns (uint256);
}

contract SimKingdomReserves is Test {
  address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
  address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
  address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
  address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
  address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
  bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;
  bytes32 constant GUSD_RSS = 0x5dd0f7c171f7de8899ca1025bfd9ee2fe2153762c532b691b1bdb344f46227cf;

  function testRepayAndSeatEusd() external {
    (address l, address c, address o, address i, uint256 lltv) = IMorpho(MORPHO).idToMarketParams(EUSD_RSS);
    (address gl, address gc, address go, address gi, uint256 glltv) = IMorpho(MORPHO).idToMarketParams(GUSD_RSS);
    (,uint128 borrowShares,) = IMorpho(MORPHO).position(GUSD_RSS, HOT);

    vm.startPrank(HOT);
    uint256 need = 72_000_000 ether + 1_500_000_000 ether;
    IMorpho(MORPHO).withdraw(IMorpho.MarketParams(l,c,o,i,lltv), need, 0, SAFE, HOT);

    IERC20(EUSD).approve(GUSD, 72_000_000 ether);
    IGusd(GUSD).wrap(72_000_000 ether, HOT);
    uint256 g = IGusd(GUSD).balanceOf(HOT);
    IERC20(GUSD).approve(MORPHO, g);
    (uint256 repaid,) = IMorpho(MORPHO).repay(
      IMorpho.MarketParams(gl,gc,go,gi,glltv), 0, borrowShares, HOT, ""
    );
    console2.log("repaid", repaid);
    (,uint128 b2,) = IMorpho(MORPHO).position(GUSD_RSS, HOT);
    require(b2 == 0, "borrow left");
    // leftover gUSD after repay interest buffer
    console2.log("gUSD left", IGusd(GUSD).balanceOf(HOT));
    console2.log("eUSD reserve", IERC20(EUSD).balanceOf(HOT));
    require(IERC20(EUSD).balanceOf(HOT) >= 1_500_000_000 ether, "eusd reserve");
    vm.stopPrank();
  }
}
