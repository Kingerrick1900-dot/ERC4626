// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";
import {CrownElephantIntent8888} from "../src/stack/CrownElephantIntent8888.sol";
import {CrownZkMesh} from "../src/zk/CrownZkMesh.sol";
import {MorphoRssOracle} from "../src/MorphoRssOracle.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IPsmSeed {
    function seedUsdc(uint256 amt) external;
    function usdcReserve() external view returns (uint256);
}

interface IMorphoMkt {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice Finish V4: seed PSM → 8020 → mesh → 8888 → $50k oracle market.
/// KING_GO=1 FIRE_V4=1 LANDING_PRIVATE_KEY=… PRIVATE_KEY=…
contract FireV4Complete is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant BASE_PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant BASE_POR = 0x3640f1CC913B772EA4D9BDF96a67196590058379;
    address constant GUSD_LIVE = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant BOUND = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant ELEPAN_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant SETTLE_GATE = 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637;
    uint256 constant LLTV = 770000000000000000;
    uint64 constant CHAIN_BASE = 8453;
    uint64 constant CHAIN_SCROLL = 534352;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_V4", uint256(0)) == 1, "NEED FIRE_V4=1");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "NOT_HOT");
        uint256 landPk = vm.envOr("LANDING_PRIVATE_KEY", hotPk);

        // 1) Pull Landing USDC → HOT for PSM seed
        uint256 landUsdc = IERC20F(USDC).balanceOf(LANDING);
        if (landUsdc > 0 && landPk != hotPk) {
            vm.startBroadcast(landPk);
            IERC20F(USDC).transfer(HOT, landUsdc);
            vm.stopBroadcast();
            console2.log("landedUsdcToHot", landUsdc);
        }

        vm.startBroadcast(hotPk);

        // 2) Seed Base PSM (owner = HOT)
        uint256 hotUsdc = IERC20F(USDC).balanceOf(HOT);
        if (hotUsdc > 0) {
            IERC20F(USDC).approve(BASE_PSM, hotUsdc);
            IPsmSeed(BASE_PSM).seedUsdc(hotUsdc);
            console2.log("psmSeeded", hotUsdc);
        }
        console2.log("psmReserve", IPsmSeed(BASE_PSM).usdcReserve());

        // 3) Sync 8020 (2-arg redeem)
        CrownSyncRedeem8020 sync = new CrownSyncRedeem8020(EUSD, GUSD_LIVE, BASE_PSM, USDC, HOT);
        console2.log("sync8020", address(sync));
        console2.log("maxRedeemSync", sync.maxRedeemSync(HOT));

        // 4) Mesh + 8888
        CrownZkMesh mesh = new CrownZkMesh(HOT);
        mesh.wire(CHAIN_BASE, BOUND, ELEPAN_GATE, SETTLE_GATE);
        // Scroll gate addresses mirrored for registry (execution still on Base for now)
        mesh.wire(CHAIN_SCROLL, BOUND, ELEPAN_GATE, SETTLE_GATE);
        console2.log("mesh", address(mesh));
        console2.log("meshProvenHot", mesh.isProvenHere(HOT));

        CrownElephantIntent8888 elephant = new CrownElephantIntent8888(SETTLE_GATE, HOT);
        console2.log("elephant8888", address(elephant));

        // 5) $50k oracle + Morpho market (NEW book — does not touch $1200 AMO)
        MorphoRssOracle oracle50 = new MorphoRssOracle(50_000);
        console2.log("oracle50k", address(oracle50));
        console2.log("oraclePrice", oracle50.price());

        IMorphoMkt.MarketParams memory mp = IMorphoMkt.MarketParams({
            loanToken: EUSD,
            collateralToken: RSS,
            oracle: address(oracle50),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoMkt(MORPHO).createMarket(mp);
        bytes32 mid = keccak256(abi.encode(mp));
        console2.logBytes32(mid);
        (address loan,,,,) = IMorphoMkt(MORPHO).idToMarketParams(mid);
        require(loan == EUSD, "MKT_FAIL");

        // Brand: wrap more eUSD → gUSD if float available
        uint256 wrapAmt = vm.envOr("WRAP_GUSD", uint256(10_000e18));
        uint256 eBal = IERC20F(EUSD).balanceOf(HOT);
        if (wrapAmt > eBal) wrapAmt = eBal;
        if (wrapAmt > 0) {
            IERC20F(EUSD).approve(GUSD_LIVE, wrapAmt);
            CrownGoldUsd(GUSD_LIVE).wrap(wrapAmt, HOT);
            console2.log("gusdWrapped", wrapAmt);
        }

        vm.stopBroadcast();
        console2.log("V4_COMPLETE", uint256(1));
    }
}
