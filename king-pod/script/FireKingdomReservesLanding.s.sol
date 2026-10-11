// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoL {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32)
        external
        view
        returns (address, address, address, address, uint256);

    function position(bytes32, address) external view returns (uint256, uint128, uint128);

    function market(bytes32)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function withdraw(MarketParams memory, uint256, uint256, address, address)
        external
        returns (uint256, uint256);
}

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IPairL {
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
}

/// @notice FIRE_KINGDOM_RESERVES_LANDING=1 · LANDING_PRIVATE_KEY · ZK_SHIELD=1
/// @dev Burn 1.5B ocean LP → HOT (1.5B gUSD + 1.5B eUSD). Withdraw Morpho gUSD supply → HOT (King 30M+).
///      Run AFTER FireKingdomReservesHot (repay unlocks full Landing supply).
contract FireKingdomReservesLanding is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant OCEAN = 0x8C009d9654247Bc2B68DE98b3083B27aF8f2eFE7;
    bytes32 constant GUSD_RSS = 0x5dd0f7c171f7de8899ca1025bfd9ee2fe2153762c532b691b1bdb344f46227cf;

    uint256 constant OCEAN_LP = 1_500_000_000 ether;

    function run() external {
        require(vm.envOr("FIRE_KINGDOM_RESERVES_LANDING", uint256(0)) == 1, "FIRE_KINGDOM_RESERVES_LANDING");
        // Landing may be unproven; Safe-proven custody path (KING_CUSTODY_OK=1).
        ZkShieldLaw.requireKingCustody(LANDING);

        uint256 pk = vm.envUint("LANDING_PRIVATE_KEY");
        require(vm.addr(pk) == LANDING, "NOT_LANDING");

        uint256 lpBal = IERC20L(OCEAN).balanceOf(LANDING);
        require(lpBal >= OCEAN_LP, "LP_LOW");

        (address gl, address gc, address go, address gi, uint256 glltv) =
            IMorphoL(MORPHO).idToMarketParams(GUSD_RSS);
        (uint256 supplyShares,,) = IMorphoL(MORPHO).position(GUSD_RSS, LANDING);
        require(supplyShares > 0, "NO_SUPPLY");

        uint256 gBefore = IERC20L(GUSD).balanceOf(HOT);
        uint256 eBefore = IERC20L(EUSD).balanceOf(HOT);

        vm.startBroadcast(pk);
        // Ocean peel: 1.5B LP → ~1.5B gUSD + ~1.5B eUSD to HOT
        require(IERC20L(OCEAN).transfer(OCEAN, OCEAN_LP), "LP_XFER");
        (uint256 a0, uint256 a1) = IPairL(OCEAN).burn(HOT);

        // King Morpho gUSD: withdraw all Landing supply shares to HOT
        IMorphoL(MORPHO).withdraw(
            IMorphoL.MarketParams(gl, gc, go, gi, glltv), 0, supplyShares, LANDING, HOT
        );
        vm.stopBroadcast();

        uint256 gDelta = IERC20L(GUSD).balanceOf(HOT) - gBefore;
        uint256 eDelta = IERC20L(EUSD).balanceOf(HOT) - eBefore;
        require(gDelta >= 1_500_000_000 ether, "GUSD_OCEAN");
        // ocean eUSD leg + morpho path may stack; require at least ocean 1.5B eUSD in delta
        require(eDelta >= 1_500_000_000 ether, "EUSD_OCEAN");
        // King 30M: Morpho liquid was ~30M pre-repay; post-repay full ~100M lands on HOT
        require(gDelta >= 1_530_000_000 ether, "KING_30M");

        console2.log("OCEAN_BURN_A0", a0);
        console2.log("OCEAN_BURN_A1", a1);
        console2.log("HOT_GUSD_DELTA", gDelta);
        console2.log("HOT_EUSD_DELTA", eDelta);
        console2.log("HOT_GUSD", IERC20L(GUSD).balanceOf(HOT));
        console2.log("HOT_EUSD", IERC20L(EUSD).balanceOf(HOT));
        console2.log("LANDING_LP_LEFT", IERC20L(OCEAN).balanceOf(LANDING));
        (uint256 shLeft,,) = IMorphoL(MORPHO).position(GUSD_RSS, LANDING);
        console2.log("LANDING_GUSD_SHARES_LEFT", shLeft);
    }
}
