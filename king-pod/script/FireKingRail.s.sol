// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKingRail} from "../src/CrownKingRail.sol";
import {CrownOceanSeeder} from "../src/CrownOceanSeeder.sol";

interface IMorphoS {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy CrownKingRail, wire markets, fire P2 eUSD pipe, push ocean toward 5B.
/// @dev KING_GO=1 forge script script/FireKingRail.s.sol:FireKingRailDeploy --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireKingRailDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant OCEAN = 0x5AE22813c4560fA28a3C2e4c7e918Da42904c099;

    bytes32 constant EUSD_MKT = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant CBBTC_MKT = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address l0, address c0, address o0,, uint256 lltv0) = IMorphoS(MORPHO).idToMarketParams(EUSD_MKT);
        (address l1, address c1, address o1,,) = IMorphoS(MORPHO).idToMarketParams(PARK);
        (address l2, address c2, address o2,, uint256 lltv2) = IMorphoS(MORPHO).idToMarketParams(CBBTC_MKT);
        require(l0 == EUSD && c0 == RSS, "EUSD_MKT");
        require(l1 == USDC && c1 == RSS, "PARK");
        require(l2 == USDC && c2 == CBBTC, "CBBTC");

        uint256 pipeAmt = vm.envOr("P2_AMT", uint256(2_000_000e18));
        bool doOcean = vm.envOr("OCEAN_TO_5B", uint256(1)) == 1;
        // 5B target − ~1.021B live ≈ 3.979B per side
        uint256 oceanSide = vm.envOr("OCEAN_SIDE", uint256(3_979_000_000e18));

        vm.startBroadcast(pk);

        CrownKingRail rail = new CrownKingRail(MORPHO, USDC, EUSD, CBBTC, YRSS, HOT, LANDING, HOT);
        rail.setMarkets(RSS, o0, o1, o2, IRM, lltv0, lltv2, EUSD_MKT, PARK, CBBTC_MKT);
        rail.setArmed(true);
        rail.setMinIdleBuffer(1_500_000e6);

        // P2 — pipe 2M eUSD to Landing (HOT free balance)
        uint256 bal = IERC20S(EUSD).balanceOf(HOT);
        if (pipeAmt > bal) pipeAmt = bal;
        if (pipeAmt > 0) {
            IERC20S(EUSD).approve(address(rail), pipeAmt);
            uint256 got = rail.p2PipeEusdToLanding(pipeAmt);
            console2.log("p2_piped", got);
        }

        if (doOcean && oceanSide > 0) {
            CrownOceanSeeder(OCEAN).seedOcean(oceanSide);
            console2.log("ocean_side", oceanSide);
        }

        vm.stopBroadcast();

        console2.log("CrownKingRail", address(rail));
        console2.log("idleEusd", rail.idleEusd());
        console2.log("idlePark", rail.idlePark());
        console2.log("P4_coll", "cbBTC");
        console2.log("P3_P4_armed", "need cbBTC on HOT + yrss.approve");
    }
}
