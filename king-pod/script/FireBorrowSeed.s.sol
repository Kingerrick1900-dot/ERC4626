// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBorrowSeed} from "../src/CrownBorrowSeed.sol";

interface IMorphoV {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Fresh borrow on HOT RSS collateral → CrownPoolEngineer.seedFromUsdc (when market idle ≥ amt).
contract FireBorrowSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ENG = 0x4D42bBD373CE058959b8b2211DF4cCDa6cb3E3ff;
    address constant POOL = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        uint256 amt = vm.envOr("SEED_USDC", uint256(500_000e6));

        (uint128 supply,, uint128 borrow,,,) = IMorphoV(MORPHO).market(PARK);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        console2.log("parkIdle", idle);
        require(idle >= amt, "NO_IDLE");

        uint256 poolBefore = IERC20b(USDC).balanceOf(POOL);
        console2.log("poolUsdcBefore", poolBefore);

        vm.startBroadcast(pk);

        CrownBorrowSeed helper = new CrownBorrowSeed(MORPHO, ENG, USDC, HOT, PARK, HOT);
        IMorphoV(MORPHO).setAuthorization(address(helper), true);
        helper.borrowAndSeed(amt);

        vm.stopBroadcast();

        console2.log("CrownBorrowSeed", address(helper));
        console2.log("poolUsdcAfter", IERC20b(USDC).balanceOf(POOL));
        console2.log("seeded", amt);
    }
}
