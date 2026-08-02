// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownForceShareUsdc} from "../src/CrownForceShareUsdc.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoA {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function accrueInterest(MarketParams memory) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
}

interface IVault {
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice KING_GO=1 FIRE_FORCE_SHARE=1 MODE=vault|ten
contract FireForceShareUsdc is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELEK = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant ORACLE_77 = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_FORCE_SHARE", uint256(0)) == 1, "NEED FIRE_FORCE_SHARE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        string memory mode = vm.envOr("MODE", string("vault"));
        uint256 usdc0 = IERC20(USDC).balanceOf(HOT);

        CrownForceShareUsdc helper = CrownForceShareUsdc(vm.envOr("FORCE_HELPER", address(0)));
        vm.startBroadcast(pk);
        if (address(helper) == address(0) || address(helper).code.length == 0) {
            helper = new CrownForceShareUsdc(HOT);
            console2.log("deployed", address(helper));
        }

        if (keccak256(bytes(mode)) == keccak256(bytes("vault"))) {
            IMorphoA.MarketParams memory mp =
                IMorphoA.MarketParams(USDC, ELE, ORACLE_77, IRM, LLTV_77);
            IMorphoA(MORPHO).accrueInterest(mp);
            uint256 shares = IVault(YELEK).balanceOf(HOT);
            uint256 assets = IVault(YELEK).convertToAssets(shares);
            console2.log("yelekAssets", assets);
            require(assets >= 1e6, "NO_VAULT_DUST");
            IVault(YELEK).approve(address(helper), type(uint256).max);
            helper.forceVault(
                YELEK,
                CrownForceShareUsdc.MarketParams(USDC, ELE, ORACLE_77, IRM, LLTV_77),
                assets,
                HOT
            );
        } else if (keccak256(bytes(mode)) == keccak256(bytes("ten"))) {
            require(vm.envOr("FORCE_TEN", uint256(0)) == 1, "NEED FORCE_TEN=1");
            if (!IMorphoA(MORPHO).isAuthorized(HOT, address(helper))) {
                IMorphoA(MORPHO).setAuthorization(address(helper), true);
            }
            IMorphoA.MarketParams memory mp =
                IMorphoA.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);
            IMorphoA(MORPHO).accrueInterest(mp);
            (, uint128 borShares,) = IMorphoA(MORPHO).position(TEN, HOT);
            (,, uint128 ba, uint128 bs,,) = IMorphoA(MORPHO).market(TEN);
            uint256 debt = (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
            console2.log("tenDebt", debt);
            helper.forceMorphoSupply(
                CrownForceShareUsdc.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915), debt, HOT
            );
        } else {
            revert("MODE");
        }
        vm.stopBroadcast();

        console2.log("hotUsdcBefore", usdc0);
        console2.log("hotUsdcAfter", IERC20(USDC).balanceOf(HOT));
        console2.log("FORCE_HELPER", address(helper));
        console2.log("FORCE_SHARE_OK", uint256(1));
    }
}
