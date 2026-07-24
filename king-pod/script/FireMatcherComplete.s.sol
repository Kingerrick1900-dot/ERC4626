// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20M {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface ILoanComplete {
    function complete(uint256 amount) external returns (uint256);
    function maxAsk() external view returns (uint256);
    function landing() external view returns (address);
}

/// @notice Matcher one-shot: approve + complete(ASK) → Landing.
/// @dev MATCHER_KEY (or PRIVATE_KEY) must hold ASK USDC.
///      KING_GO=1 FIRE_LOAN_MATCH=1 ASK_USDC=500000000000
contract FireMatcherComplete is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant COMPLETER = 0x12514e1f999131eA78D402a7258b67A65F9342Ff;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_LOAN_MATCH", uint256(0)) == 1, "NEED FIRE_LOAN_MATCH=1");

        uint256 pk = vm.envOr("MATCHER_KEY", uint256(0));
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        address matcher = vm.addr(pk);

        uint256 ask = vm.envOr("ASK_USDC", uint256(500_000e6));
        uint256 maxAsk = ILoanComplete(COMPLETER).maxAsk();
        require(ask > 0 && ask <= maxAsk, "ASK");
        require(ILoanComplete(COMPLETER).landing() == LANDING, "LANDING");
        require(IERC20M(USDC).balanceOf(matcher) >= ask, "MATCHER_USDC");

        uint256 before = IERC20M(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        require(IERC20M(USDC).approve(COMPLETER, ask), "APPROVE");
        uint256 landingAfter = ILoanComplete(COMPLETER).complete(ask);
        vm.stopBroadcast();

        require(landingAfter >= before + ask, "LANDING_MISS");
        console2.log("matcher", matcher);
        console2.log("ask", ask);
        console2.log("landingUsdc", landingAfter);
        console2.log("LOAN_COMPLETE_OK", uint256(1));
    }
}
