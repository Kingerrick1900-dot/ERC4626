// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownDeallocSeed} from "../src/CrownDeallocSeed.sol";

interface IMeta {
    function setIsAllocator(address, bool) external;
    function approve(address, uint256) external returns (bool);
    function maxWithdraw(address) external view returns (uint256);
}

interface IEng {
    function setOperator(address, bool) external;
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Dealloc yRSS via flash idle → seedFromUsdc on live CrownPoolEngineer.
contract FireDeallocSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ENG = 0x4D42bBD373CE058959b8b2211DF4cCDa6cb3E3ff;
    address constant POOL = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        uint256 amt = vm.envOr("SEED_USDC", uint256(500e6));

        uint256 poolBefore = IERC20b(USDC).balanceOf(POOL);
        console2.log("maxWithdrawBefore", IMeta(YRSS).maxWithdraw(HOT));
        console2.log("poolUsdcBefore", poolBefore);

        vm.startBroadcast(pk);

        CrownDeallocSeed helper = new CrownDeallocSeed(MORPHO, YRSS, ENG, USDC, HOT, PARK, HOT);
        IMeta(YRSS).setIsAllocator(address(helper), true);
        IMeta(YRSS).approve(address(helper), type(uint256).max);
        IEng(ENG).setOperator(address(helper), true);
        helper.deallocAndSeed(amt);

        vm.stopBroadcast();

        console2.log("CrownDeallocSeed", address(helper));
        console2.log("maxWithdrawAfter", IMeta(YRSS).maxWithdraw(HOT));
        console2.log("poolUsdcAfter", IERC20b(USDC).balanceOf(POOL));
        console2.log("seeded", amt);
    }
}
