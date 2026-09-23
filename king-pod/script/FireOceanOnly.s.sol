// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";
import {CrownOceanSeeder} from "../src/CrownOceanSeeder.sol";
interface IEusdF { function setMinter(address,bool) external; function isMinter(address) external view returns (bool); }
contract FireOceanOnly is Script {
  address constant HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
  address constant LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
  address constant EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
  address constant GUSD=0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
  address constant ROUTER=0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
  function run() external {
    require(vm.envOr("KING_GO", uint256(0))==1,"NO_GO");
    uint256 pk=vm.envUint("PRIVATE_KEY");
    require(vm.addr(pk)==HOT,"NOT_HOT");
    uint256 side=vm.envOr("OCEAN_SIDE", uint256(1_000_000e18));
    vm.startBroadcast(pk);
    CrownOceanSeeder ocean=new CrownOceanSeeder(EUSD,GUSD,ROUTER,HOT,LANDING,HOT);
    IEusdF(EUSD).setMinter(address(ocean), true);
    ocean.setArmed(true);
    uint256 liq=ocean.seedOcean(side);
    vm.stopBroadcast();
    console2.log("ocean", address(ocean));
    console2.log("liq", liq);
  }
}
