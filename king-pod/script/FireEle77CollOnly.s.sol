// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice OPERATIONAL: collateral-only +ELE into ELE77. No borrow. No seed.
/// @dev KING_GO=1 FIRE_ELE77_COLL=1 COLL_ELE=3500000000000000 (35M @ 8dp)
contract FireEle77CollOnly is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_77 = 770000000000000000;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    uint256 constant DEFAULT_COLL = 35_000_000e8; // 35M ELE
    uint256 constant TARGET_COLL = 60_000_000e8; // 60M ELE

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ELE77_COLL", uint256(0)) == 1, "NEED FIRE_ELE77_COLL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 addColl = vm.envOr("COLL_ELE", DEFAULT_COLL);
        require(addColl > 0, "AMT");

        (, uint128 borrowSharesBefore, uint128 collBefore) = IMorphoC(MORPHO).position(ELE77, HOT);
        (uint128 saBefore,, uint128 baBefore,,,) = IMorphoC(MORPHO).market(ELE77);
        uint256 freeBefore = IERC20C(ELE).balanceOf(HOT);

        console2.log("collBefore", uint256(collBefore));
        console2.log("borrowSharesBefore", uint256(borrowSharesBefore));
        console2.log("marketBorrowBefore", uint256(baBefore));
        console2.log("marketSupplyBefore", uint256(saBefore));
        console2.log("freeEleBefore", freeBefore);
        console2.log("addColl", addColl);

        require(freeBefore >= addColl, "INSUFFICIENT_ELE");
        require(uint256(collBefore) + addColl == TARGET_COLL, "TARGET_60M");

        IMorphoC.MarketParams memory mp =
            IMorphoC.MarketParams({loanToken: USDC, collateralToken: ELE, oracle: ORACLE, irm: IRM, lltv: LLTV_77});

        vm.startBroadcast(pk);
        IERC20C(ELE).approve(MORPHO, addColl);
        IMorphoC(MORPHO).supplyCollateral(mp, addColl, HOT, "");
        vm.stopBroadcast();

        (, uint128 borrowSharesAfter, uint128 collAfter) = IMorphoC(MORPHO).position(ELE77, HOT);
        (uint128 saAfter,, uint128 baAfter,,,) = IMorphoC(MORPHO).market(ELE77);
        uint256 freeAfter = IERC20C(ELE).balanceOf(HOT);

        console2.log("collAfter", uint256(collAfter));
        console2.log("borrowSharesAfter", uint256(borrowSharesAfter));
        console2.log("marketBorrowAfter", uint256(baAfter));
        console2.log("marketSupplyAfter", uint256(saAfter));
        console2.log("freeEleAfter", freeAfter);

        require(uint256(collAfter) == TARGET_COLL, "COLL_NOT_60M");
        require(borrowSharesAfter == borrowSharesBefore, "DEBT_CHANGED");
        require(baAfter == baBefore, "MARKET_BORROW_CHANGED");
        require(saAfter == saBefore, "MARKET_SUPPLY_CHANGED"); // no seed
        require(freeBefore - freeAfter == addColl, "FREE_DELTA");

        // Headroom @ $1 / 77%: coll 8dp → USD 6dp = coll/100
        uint256 collUsd6 = uint256(collAfter) / 100;
        uint256 maxBorrow = (collUsd6 * 77) / 100;
        uint256 headroom = maxBorrow > uint256(baAfter) ? maxBorrow - uint256(baAfter) : 0;
        console2.log("maxBorrow77", maxBorrow);
        console2.log("headroom", headroom);
        console2.log("ELE77_COLL_ONLY_OK", uint256(1));
    }
}
