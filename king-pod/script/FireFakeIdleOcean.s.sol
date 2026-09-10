// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFakeIdleEusd} from "../src/CrownFakeIdleEusd.sol";
import {CrownOceanSeeder} from "../src/CrownOceanSeeder.sol";

interface IMorphoF {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20F {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IEusdF {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
    function mint(address, uint256) external;
}

/// @dev KING_GO=1 forge script script/FireFakeIdleOcean.s.sol:FireFakeIdleDeploy --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireFakeIdleDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    bytes32 constant MKT_EUSD = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoF(MORPHO).idToMarketParams(MKT_EUSD);
        require(loan == EUSD, "LOAN");

        uint256 engAmt = vm.envOr("FAKE_IDLE_AMT", uint256(2_000_000e18));
        bool doOcean = vm.envOr("OCEAN", uint256(0)) == 1;
        uint256 oceanSide = vm.envOr("OCEAN_SIDE", uint256(1_000_000e18)); // 1M per side default when armed

        (uint128 s0,, uint128 b0,,,) = IMorphoF(MORPHO).market(MKT_EUSD);
        uint256 idle0 = uint256(s0) > uint256(b0) ? uint256(s0) - uint256(b0) : 0;

        vm.startBroadcast(pk);

        CrownFakeIdleEusd fake = new CrownFakeIdleEusd(MORPHO, EUSD, HOT, HOT);
        fake.setMarket(coll, oracle, irm, lltv, MKT_EUSD);
        fake.setArmed(true);
        // mint path optional — first fire uses HOT free eUSD
        fake.setMintEnabled(false);

        IERC20F(EUSD).approve(address(fake), engAmt);
        uint256 supplied = fake.engineerFakeIdle(engAmt, false);

        address oceanAddr;
        if (doOcean) {
            CrownOceanSeeder ocean = new CrownOceanSeeder(EUSD, GUSD, ROUTER, HOT, LANDING, HOT);
            // allow seeder to mint
            IEusdF(EUSD).setMinter(address(ocean), true);
            ocean.setArmed(true);
            ocean.seedOcean(oceanSide);
            oceanAddr = address(ocean);
        }

        vm.stopBroadcast();

        (uint128 s1,, uint128 b1,,,) = IMorphoF(MORPHO).market(MKT_EUSD);
        uint256 idle1 = uint256(s1) > uint256(b1) ? uint256(s1) - uint256(b1) : 0;

        console2.log("CrownFakeIdleEusd", address(fake));
        console2.log("supplied", supplied);
        console2.log("idle_before", idle0);
        console2.log("idle_after", idle1);
        console2.log("utilBps", fake.utilBps());
        if (doOcean) console2.log("CrownOceanSeeder", oceanAddr);
    }
}

/// @dev KING_GO=1 FIRE=1 FAKE=0x… AMT=… MINT=0|1 forge script …:FireFakeIdleMore --broadcast --slow
contract FireFakeIdleMore is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE", uint256(0)) == 1, "NO_FIRE");
        address fakeAddr = vm.envAddress("FAKE");
        uint256 amt = vm.envOr("AMT", uint256(2_000_000e18));
        bool mintFirst = vm.envOr("MINT", uint256(0)) == 1;
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownFakeIdleEusd fake = CrownFakeIdleEusd(fakeAddr);

        vm.startBroadcast(pk);
        if (mintFirst) {
            // ensure contract can mint
            if (!IEusdF(EUSD).isMinter(fakeAddr)) {
                IEusdF(EUSD).setMinter(fakeAddr, true);
            }
            fake.setMintEnabled(true);
        } else {
            IERC20F(EUSD).approve(fakeAddr, amt);
        }
        uint256 supplied = fake.engineerFakeIdle(amt, mintFirst);
        vm.stopBroadcast();

        console2.log("supplied", supplied);
        console2.log("idle", fake.idle());
    }
}

/// @dev KING_GO=1 FIRE_OCEAN=1 OCEAN=0x… SIDE=… forge script …:FireOceanSeed --broadcast --slow
contract FireOceanSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_OCEAN", uint256(0)) == 1, "NO_FIRE");
        address oceanAddr = vm.envAddress("OCEAN");
        uint256 side = vm.envOr("SIDE", uint256(1_000_000e18));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownOceanSeeder ocean = CrownOceanSeeder(oceanAddr);
        vm.startBroadcast(pk);
        if (!IEusdF(EUSD).isMinter(oceanAddr)) {
            IEusdF(EUSD).setMinter(oceanAddr, true);
        }
        uint256 liq = ocean.seedOcean(side);
        vm.stopBroadcast();
        console2.log("liquidity", liq);
    }
}
