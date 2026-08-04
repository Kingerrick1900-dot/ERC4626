// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoF4 {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function authorize(address, bool) external; // may not exist - Morpho uses setAuthorization
}

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IERC20F4 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IPsmF4 {
    function redeem(uint256 eusdIn, address receiver) external returns (uint256 usdcOut);
    function usdcReserve() external view returns (uint256);
}

interface IAutoDrawF4 {
    function poke() external returns (uint256 amount);
    function quote() external view returns (uint256 maxB, bool proven, uint256 creditUsdc);
}

interface ICompleterF4 {
    function complete(uint256 amount) external returns (uint256);
    function maxAsk() external view returns (uint256);
}

/// @notice FIRE ALL FOUR live avenues — execution, not dashboard.
/// @dev A1 Completer/AutoDraw · A3 PSM redeem + eUSD treasury · A4 Morpho idle borrow → Landing
///      A2 Tenor is offchain (FireTenorRssRfq500k.py) — fired in parallel by wrapper.
///      FIRE=1 broadcasts. No flash theater. Elepan never touched.
contract FireFourNow is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant PSM = 0xfFEd7981f924Edc652E9b767aCa601505dfa4977;
    address constant AUTODRAW = 0x364bEF6c5A3DC2c02D7ECf1e12a2d1F08B0513ba;
    address constant COMPLETER = 0xA247c1d0Ad4E7690764E456E5d8d315bA2912468;
    address constant CREDIT = 0x20B1513a137b9CB166E2cC15c405e842278E7D1A;

    function run() external {
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        require(IERC20F4(RSS).balanceOf(HOT) == IERC20F4(RSS).balanceOf(HOT), "noop");
        require(ELEPAN != RSS, "ELEPAN");

        uint256 land0 = IERC20F4(USDC).balanceOf(LANDING);
        (uint128 supply,, uint128 borrow,,,) = IMorphoF4(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        (, uint128 bShares, uint128 coll) = IMorphoF4(MORPHO).position(MARKET_ID, HOT);
        uint256 hotUsdc = IERC20F4(USDC).balanceOf(HOT);
        uint256 creditUsdc = IERC20F4(USDC).balanceOf(CREDIT);
        uint256 psmUsdc = IERC20F4(USDC).balanceOf(PSM);
        uint256 hotEusd = IERC20F4(EUSD).balanceOf(HOT);
        (uint256 maxB,,) = IAutoDrawF4(AUTODRAW).quote();
        uint256 maxAsk = ICompleterF4(COMPLETER).maxAsk();

        console2.log("=== FIRE FOUR NOW ===");
        console2.log("Landing USDC before", land0);
        console2.log("A1 hotUsdc", hotUsdc);
        console2.log("A1 creditUsdc", creditUsdc);
        console2.log("A1 maxAsk", maxAsk);
        console2.log("A1 autodraw maxB", maxB);
        console2.log("A3 psmUsdc", psmUsdc);
        console2.log("A3 hotEusd", hotEusd);
        console2.log("A4 idle", idle);
        console2.log("A4 coll", uint256(coll));
        console2.log("A4 borrowShares", uint256(bShares));

        if (!fire) {
            console2.log("DRY - set FIRE=1");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        vm.startBroadcast(pk);

        // ---- A1 Bound Completer / AutoDraw (only if liquidity — never broadcast a revert) ----
        if (hotUsdc > 0 && hotUsdc <= maxAsk) {
            require(IERC20F4(USDC).approve(COMPLETER, hotUsdc), "A1_APPROVE");
            uint256 afterC = ICompleterF4(COMPLETER).complete(hotUsdc);
            console2.log("A1_COMPLETE Landing", afterC);
        } else if (creditUsdc > 0 && maxB > 0) {
            uint256 poked = IAutoDrawF4(AUTODRAW).poke();
            console2.log("A1_POKE", poked);
        } else {
            console2.log("A1_ARMED_WAITING_USDC maxAsk", maxAsk);
        }

        // ---- A3 eUSD unlock: redeem PSM floor to Landing + park remaining hot eUSD ----
        if (psmUsdc > 0 && hotEusd >= psmUsdc * 1e12) {
            uint256 eusdIn = psmUsdc * 1e12; // 1:1
            require(IERC20F4(EUSD).approve(PSM, eusdIn), "A3_APPROVE");
            uint256 got = IPsmF4(PSM).redeem(eusdIn, LANDING);
            console2.log("A3_PSM_REDEEM_USDC", got);
        } else {
            console2.log("A3_PSM_SKIP", psmUsdc);
        }
        uint256 eusdLeft = IERC20F4(EUSD).balanceOf(HOT);
        if (eusdLeft > 0) {
            require(IERC20F4(EUSD).transfer(LANDING, eusdLeft), "A3_EUSD");
            console2.log("A3_EUSD_TO_LANDING", eusdLeft);
        }

        // ---- A4 Morpho idle borrow → Landing (live depth, whatever idle is) ----
        if (idle > 0 && uint256(coll) > 0 && uint256(bShares) > 0) {
            // headroom check rough: leave 1 wei idle buffer if needed
            uint256 ask = idle > 1 ? idle - 1 : idle;
            IMorphoF4.MarketParams memory mp = IMorphoF4.MarketParams({
                loanToken: USDC,
                collateralToken: RSS,
                oracle: ORACLE,
                irm: IRM,
                lltv: LLTV
            });
            IMorphoF4(MORPHO).borrow(mp, ask, 0, HOT, LANDING);
            console2.log("A4_BORROW_TO_LANDING", ask);
        } else {
            console2.log("A4_SKIP idle/coll/debt", idle);
        }

        vm.stopBroadcast();

        uint256 land1 = IERC20F4(USDC).balanceOf(LANDING);
        console2.log("Landing USDC after", land1);
        console2.log("Landing USDC delta", land1 - land0);
        console2.log("FIRE_FOUR_OK");
    }
}
