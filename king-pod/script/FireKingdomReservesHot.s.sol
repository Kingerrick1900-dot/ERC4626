// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoR {
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

    function withdraw(MarketParams memory, uint256, uint256, address, address)
        external
        returns (uint256, uint256);

    function repay(MarketParams memory, uint256, uint256, address, bytes calldata)
        external
        returns (uint256, uint256);
}

interface IERC20R {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IGusdR {
    function wrap(uint256, address) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @notice FIRE_KINGDOM_RESERVES_HOT=1 · HOT_KEY · ZK_SHIELD=1
/// @dev Withdraw eUSD from Safe Morpho → wrap buffer → repay HOT gUSD borrow → seat 1.5B eUSD on HOT.
contract FireKingdomReservesHot is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;
    bytes32 constant GUSD_RSS = 0x5dd0f7c171f7de8899ca1025bfd9ee2fe2153762c532b691b1bdb344f46227cf;

    uint256 constant RESERVE = 1_500_000_000 ether;
    uint256 constant WRAP_BUF = 72_000_000 ether;

    function run() external {
        require(vm.envOr("FIRE_KINGDOM_RESERVES_HOT", uint256(0)) == 1, "FIRE_KINGDOM_RESERVES_HOT");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address el, address ec, address eo, address ei, uint256 elltv) =
            IMorphoR(MORPHO).idToMarketParams(EUSD_RSS);
        (address gl, address gc, address go, address gi, uint256 glltv) =
            IMorphoR(MORPHO).idToMarketParams(GUSD_RSS);
        (, uint128 borrowShares,) = IMorphoR(MORPHO).position(GUSD_RSS, HOT);
        require(borrowShares > 0, "NO_BORROW");

        uint256 need = WRAP_BUF + RESERVE;

        vm.startBroadcast(pk);
        IMorphoR(MORPHO).withdraw(
            IMorphoR.MarketParams(el, ec, eo, ei, elltv), need, 0, SAFE, HOT
        );
        IERC20R(EUSD).approve(GUSD, WRAP_BUF);
        IGusdR(GUSD).wrap(WRAP_BUF, HOT);
        uint256 g = IGusdR(GUSD).balanceOf(HOT);
        IERC20R(GUSD).approve(MORPHO, g);
        (uint256 repaid,) = IMorphoR(MORPHO).repay(
            IMorphoR.MarketParams(gl, gc, go, gi, glltv), 0, borrowShares, HOT, ""
        );
        vm.stopBroadcast();

        (, uint128 b2,) = IMorphoR(MORPHO).position(GUSD_RSS, HOT);
        require(b2 == 0, "BORROW_LEFT");
        uint256 eBal = IERC20R(EUSD).balanceOf(HOT);
        require(eBal >= RESERVE, "EUSD_RESERVE");

        console2.log("REPAID_GUSD", repaid);
        console2.log("HOT_GUSD_LEFT", IGusdR(GUSD).balanceOf(HOT));
        console2.log("HOT_EUSD_RESERVE", eBal);
    }
}
