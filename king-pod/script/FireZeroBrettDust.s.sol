// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20Z {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoZ {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

/// @notice Zero BRETT Morpho dust debt — spend hot USDC, keep BRETT collateral posted.
/// @dev KING_OK=1 KING_GO=1 FIRE_BRETT_ZERO=1
contract FireZeroBrettDust is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant ORACLE_BRETT = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    uint256 constant LLTV_BRETT = 625000000000000000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        bool doFire = vm.envOr("FIRE_BRETT_ZERO", uint256(0)) == 1;

        IMorphoZ.MarketParams memory mp =
            IMorphoZ.MarketParams(USDC, BRETT, ORACLE_BRETT, IRM, LLTV_BRETT);
        IMorphoZ(MORPHO).accrueInterest(mp);

        (, uint128 borShares, uint128 coll) = IMorphoZ(MORPHO).position(BRETT_M, HOT);
        (,, uint128 bA, uint128 bS,,) = IMorphoZ(MORPHO).market(BRETT_M);
        uint256 debt = bS == 0 || borShares == 0 ? 0 : (uint256(borShares) * uint256(bA) + uint256(bS) - 1) / uint256(bS);

        console2.log("=== ZERO BRETT DUST ===");
        console2.log("debtUsdc", debt);
        console2.log("borShares", uint256(borShares));
        console2.log("collBrett", uint256(coll));
        console2.log("hotUsdc", IERC20Z(USDC).balanceOf(HOT));
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        if (borShares == 0) {
            console2.log("ALREADY_ZERO", uint256(1));
            return;
        }

        require(debt > 0, "NO DEBT");
        require(IERC20Z(USDC).balanceOf(HOT) >= debt, "NEED HOT USDC peel Landing first");

        if (!doFire) {
            console2.log("PREFLIGHT OK - FIRE_BRETT_ZERO=1");
            return;
        }

        vm.startBroadcast(pk);
        IERC20Z(USDC).approve(MORPHO, debt);
        IMorphoZ(MORPHO).repay(mp, debt, 0, HOT, "");
        vm.stopBroadcast();

        (, uint128 borAfter, uint128 collAfter) = IMorphoZ(MORPHO).position(BRETT_M, HOT);
        console2.log("borSharesAfter", uint256(borAfter));
        console2.log("collAfter", uint256(collAfter));
        require(borAfter == 0, "STILL DEBT");
        console2.log("BRETT_ZERO_OK", uint256(1));
    }
}
