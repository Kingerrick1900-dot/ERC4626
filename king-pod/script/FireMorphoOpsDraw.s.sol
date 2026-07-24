// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20O {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracleO {
    function price() external view returns (uint256);
}

interface IMorphoO {
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

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;

    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
}

/// @notice Morpho-native ops draw: collateral proof → borrow → Landing KEEP.
/// @dev No vault. No matcher. No outside-approval gate. KING_GO=1 FIRE_MORPHO_OPS=1
contract FireMorphoOpsDraw is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MORPHO_OPS", uint256(0)) == 1, "NEED FIRE_MORPHO_OPS=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 borrowWanted = vm.envOr("BORROW_USDC", uint256(500_000e6));
        uint256 postColl = vm.envOr("COLL_ELEPAN", uint256(0)); // 8dp; 0 = use posted only

        IMorphoO.MarketParams memory mp = IMorphoO.MarketParams({
            loanToken: USDC,
            collateralToken: ELEPAN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorphoO(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(supplyAssets) - uint256(borrowAssets);

        (, uint128 borShares, uint128 coll) = IMorphoO(MORPHO).position(ELE_USDC, HOT);
        uint256 price = IOracleO(ORACLE).price(); // 1e36 scale for 1 coll unit

        // After optional post, coll for capacity math
        uint256 collAssets = uint256(coll) + postColl;
        // Elepan 8dp → value USDC 6dp: coll * price / 1e36 * 1e6 / 1e8 = coll * price / 1e38
        // Morpho oracle for 8dp coll / 6dp loan: price is typically 1e36 * (loan_decimals scaling)
        // Live oracle returned 1e34 for $1 Elepan(8) → USDC(6): value = coll * 1e34 / 1e36 = coll/1e2
        // i.e. coll_raw_8dp * price / 1e36 gives loan-token raw? Check Morpho docs:
        // collateralValue = coll * price / 1e36 (in loan token decimals)
        uint256 collValue = (collAssets * price) / 1e36;
        uint256 maxByLltv = (collValue * LLTV) / 1e18;

        // Approximate debt from market share price
        uint256 debt;
        if (borShares > 0 && borrowAssets > 0) {
            // totalBorrowShares ≈ from market tuple index 3
            (,, uint128 ba, uint128 bs,,) = IMorphoO(MORPHO).market(ELE_USDC);
            debt = (uint256(ba) * uint256(borShares) + uint256(bs) - 1) / uint256(bs);
        }
        uint256 room = maxByLltv > debt ? maxByLltv - debt : 0;

        console2.log("=== MORPHO OPS LINK ===");
        console2.log("idle", idle);
        console2.log("collAssets", collAssets);
        console2.log("collValue", collValue);
        console2.log("debt", debt);
        console2.log("roomLltv", room);
        console2.log("borrowWanted", borrowWanted);

        require(idle > 0, "NO_IDLE: open Blue supply first (permissionless)");
        require(room > 0, "NO_ROOM: post more Elepan collateral");

        uint256 borrowUsdc = borrowWanted;
        if (borrowUsdc > idle) borrowUsdc = idle;
        if (borrowUsdc > room) borrowUsdc = room;
        require(borrowUsdc > 0, "ZERO_DRAW");

        uint256 landBefore = IERC20O(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        if (postColl > 0) {
            IERC20O(ELEPAN).approve(MORPHO, postColl);
            IMorphoO(MORPHO).supplyCollateral(mp, postColl, HOT, "");
        }
        // LINK: proven collateral → USDC to Landing → KEEP (no vault)
        IMorphoO(MORPHO).borrow(mp, borrowUsdc, 0, HOT, LANDING);
        vm.stopBroadcast();

        uint256 landAfter = IERC20O(USDC).balanceOf(LANDING);
        require(landAfter >= landBefore + borrowUsdc, "LANDING_MISS: cash did not land");
        console2.log("landingDelta", landAfter - landBefore);
        console2.log("MORPHO_OPS_OK", uint256(1));
    }
}
