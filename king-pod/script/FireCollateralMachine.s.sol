// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCollateralMachine} from "../src/CrownCollateralMachine.sol";

interface IERC20F {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IPoolF {
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}

/// @notice Deploy + optional fire collateral machine.
/// @dev KING_OK=1 FIRE_COLLATERAL_MACHINE=1
///      MODE=borrow|flash (default flash dry check)
///      LIVE_FIRE=1 required to broadcast borrow/flash execute (after deploy)
///      REPAY_SOURCE for flash = Aero.swap(RSS→USDC)
contract FireCollateralMachine is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ADV = 0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant RSS_USDC_POOL = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_COLLATERAL_MACHINE", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 amt = vm.envOr("USDC_AMT", uint256(500_000e6));
        uint256 rssSell = vm.envOr("RSS_SELL", uint256(600_000 ether));
        string memory mode = vm.envOr("MODE", string("flash"));

        uint256 quote = IPoolF(RSS_USDC_POOL).getAmountOut(rssSell, RSS);
        console2.log("REPAY_SOURCE", "Aero.swap(RSS->USDC)");
        console2.log("poolQuoteUsdc", quote);
        console2.log("needUsdc", amt);

        vm.startBroadcast(pk);
        CrownCollateralMachine m = new CrownCollateralMachine(
            MORPHO,
            AERO,
            AERO_FACTORY,
            USDC,
            RSS,
            ADV,
            LANDING,
            HOT,
            MARKET_ID,
            ORACLE,
            IRM,
            LLTV,
            HOT
        );
        console2.log("CrownCollateralMachine", address(m));

        if (vm.envOr("LIVE_FIRE", uint256(0)) == 1) {
            require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_KING_GO");
            if (keccak256(bytes(mode)) == keccak256(bytes("borrow"))) {
                uint256 rssColl = vm.envOr("RSS_COLL", uint256(700_000 ether));
                IERC20F(RSS).approve(address(m), rssColl);
                m.borrowToLanding(rssColl, amt);
            } else {
                require(quote >= amt, "POOL_DEPTH_SHORT");
                IERC20F(RSS).approve(address(m), rssSell);
                m.flashAdvanceToLanding(amt, rssSell, amt);
            }
            console2.log("landingUsdc", IERC20F(USDC).balanceOf(LANDING));
        } else {
            console2.log("DEPLOY_ONLY", "set LIVE_FIRE=1 KING_GO=1 after depth/idle proven");
        }
        vm.stopBroadcast();
    }
}
