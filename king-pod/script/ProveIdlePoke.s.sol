// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}
interface IMorphoP {
    struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
    function supply(MarketParams memory, uint256, uint256, address, bytes calldata) external returns (uint256, uint256);
}
interface IPoolP {
    function idle() external view returns (uint256);
    function poke() external returns (uint256);
}

contract ProveIdlePoke is Script, StdCheats {
    function run() external {
        address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
        address MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
        address ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
        address IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
        address LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
        address POOL = 0x44F085A5be83f1c8d4880a46e165336bcaDa72F8;
        uint256 SEED = 2_000_000e6;
        address lp = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        deal(USDC, lp, SEED);
        vm.startBroadcast(lp);
        IERC20P(USDC).approve(MORPHO, SEED);
        IMorphoP(MORPHO).supply(
            IMorphoP.MarketParams(USDC, RSS, ORACLE, IRM, 770000000000000000),
            SEED, 0, lp, ""
        );
        uint256 idle = IPoolP(POOL).idle();
        console2.log("idle", idle);
        uint256 land0 = IERC20P(USDC).balanceOf(LANDING);
        uint256 delta = IPoolP(POOL).poke();
        console2.log("delta", delta);
        console2.log("landing", IERC20P(USDC).balanceOf(LANDING));
        require(delta >= SEED, "MISS");
        require(delta > 700_000e6, "CEILING");
        console2.log("POKE_OVER_700K_OK");
        vm.stopBroadcast();
    }
}
