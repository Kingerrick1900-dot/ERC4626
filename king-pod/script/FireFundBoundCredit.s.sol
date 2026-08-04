// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ICompleter {
    function complete(uint256 amount) external returns (uint256 landingAfter);
    function maxAsk() external view returns (uint256);
}

interface IAutoDraw {
    function poke() external returns (uint256 amount);
    function quote() external view returns (uint256 maxB, bool proven, uint256 creditUsdc);
}

interface ICredit {
    function supply(uint256 amt) external;
    function borrowMaxToLanding() external returns (uint256);
    function maxBorrow(address user) external view returns (uint256);
    function operator(address) external view returns (bool);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IGate {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, bool);
}

/// @notice Fund Bound credit → Landing NOW via Completer.complete (matcher path).
/// @dev Physics: msg.sender must hold USDC. Completer pulls USDC → credit.supply →
///      operatorBorrowTo(Landing). King proven @ $700k → maxAsk = $490k.
///      Env: FIRE=1, AMOUNT (6dp, default maxAsk), MODE=complete|supply_draw|poke
contract FireFundBoundCredit is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CREDIT = 0x20B1513a137b9CB166E2cC15c405e842278E7D1A;
    address constant COMPLETER = 0x3827dA0c33891ee058847BB896D6287C5814F7C6;
    address constant AUTODRAW = 0x364bEF6c5A3DC2c02D7ECf1e12a2d1F08B0513ba;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        string memory mode = vm.envOr("MODE", string("complete"));
        uint256 amount = vm.envOr("AMOUNT", uint256(0));

        uint256 maxAsk = ICompleter(COMPLETER).maxAsk();
        if (amount == 0) amount = maxAsk;

        uint256 hotUsdc = IERC20F(USDC).balanceOf(HOT);
        uint256 landingBefore = IERC20F(USDC).balanceOf(LANDING);
        uint256 creditUsdc = IERC20F(USDC).balanceOf(CREDIT);
        bool proven = IGate(GATE).isProven(HOT);
        (uint256 threshold,,) = IGate(GATE).attestations(HOT);
        (uint256 maxB, bool qProven, uint256 qCredit) = IAutoDraw(AUTODRAW).quote();

        console2.log("=== FUND BOUND CREDIT -> LANDING ===");
        console2.log("mode", mode);
        console2.log("proven", proven ? 1 : 0);
        console2.log("threshold", threshold);
        console2.log("maxAsk", maxAsk);
        console2.log("amount", amount);
        console2.log("hot USDC", hotUsdc);
        console2.log("credit USDC", creditUsdc);
        console2.log("Landing before", landingBefore);
        console2.log("autodraw maxB", maxB);
        console2.log("completer is operator", ICredit(CREDIT).operator(COMPLETER) ? 1 : 0);
        console2.log("autodraw is operator", ICredit(CREDIT).operator(AUTODRAW) ? 1 : 0);

        bool funded = hotUsdc >= amount || creditUsdc >= amount;
        console2.log("liquidity ready", funded ? 1 : 0);

        if (!fire) {
            if (!proven) console2.log("DRY BLOCKED - not proven");
            else if (!funded) console2.log("DRY BLOCKED - need USDC on hot (or credit) >= amount");
            else console2.log("DRY ARMED - FIRE=1 to complete -> Landing");
            return;
        }

        require(proven, "NOT_PROVEN");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        if (keccak256(bytes(mode)) == keccak256(bytes("complete"))) {
            require(hotUsdc >= amount, "HOT_USDC_SHORT");
            require(amount > 0 && amount <= maxAsk, "ASK");
            require(IERC20F(USDC).approve(COMPLETER, amount), "APPROVE");
            uint256 after_ = ICompleter(COMPLETER).complete(amount);
            console2.log("Landing after", after_);
            console2.log("COMPLETE_OK");
        } else if (keccak256(bytes(mode)) == keccak256(bytes("supply_draw"))) {
            // supply into credit then king borrowMaxToLanding
            require(hotUsdc >= amount, "HOT_USDC_SHORT");
            require(IERC20F(USDC).approve(CREDIT, amount), "APPROVE");
            ICredit(CREDIT).supply(amount);
            uint256 drew = ICredit(CREDIT).borrowMaxToLanding();
            console2.log("drew", drew);
            console2.log("Landing after", IERC20F(USDC).balanceOf(LANDING));
            console2.log("SUPPLY_DRAW_OK");
        } else if (keccak256(bytes(mode)) == keccak256(bytes("poke"))) {
            // credit already funded — permissionless autodraw
            require(creditUsdc > 0 && maxB > 0, "NO_CREDIT_LIQ");
            uint256 drew = IAutoDraw(AUTODRAW).poke();
            console2.log("poked", drew);
            console2.log("Landing after", IERC20F(USDC).balanceOf(LANDING));
            console2.log("POKE_OK");
        } else {
            revert("MODE");
        }

        vm.stopBroadcast();
        uint256 landingAfter = IERC20F(USDC).balanceOf(LANDING);
        console2.log("Landing delta", landingAfter - landingBefore);
        require(landingAfter > landingBefore, "LANDING_NO_GAIN");
        qProven;
        qCredit;
    }
}
