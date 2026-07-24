// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20B {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoB {
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

    function supplyCollateral(MarketParams calldata, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams calldata, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
}

/// @notice Tranche borrow: Elepan coll → USDC to Landing.
/// @dev KING_GO=1 FIRE_BORROW=1. Requires live idle ≥ IDLE_FLOOR at send (no deferred lane).
contract FireElepanBorrowUsdc is Script {
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
        require(vm.envOr("FIRE_BORROW", uint256(0)) == 1, "NEED FIRE_BORROW=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 borrowUsdc = vm.envUint("BORROW_USDC"); // raw 6dp
        uint256 idleFloor = vm.envOr("IDLE_FLOOR", uint256(100_000e6));
        uint256 collElepan = vm.envOr("COLL_ELEPAN", uint256(0)); // 8dp; 0 = borrow only against existing Morpho coll

        IMorphoB.MarketParams memory mp = IMorphoB.MarketParams({
            loanToken: USDC,
            collateralToken: ELEPAN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorphoB(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(supplyAssets) - uint256(borrowAssets);
        require(idle >= idleFloor, "IDLE_FLOOR");
        require(borrowUsdc > 0 && borrowUsdc <= idle, "BORROW_GT_IDLE");
        // Keep ≤ 50% of idle on first tranche unless King overrides
        uint256 maxFirst = vm.envOr("MAX_FIRST_BORROW_BPS", uint256(5000));
        require(borrowUsdc <= (idle * maxFirst) / 10_000, "FIRST_TRANCHE_CAP");

        uint256 landBefore = IERC20B(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        if (collElepan > 0) {
            IERC20B(ELEPAN).approve(MORPHO, collElepan);
            IMorphoB(MORPHO).supplyCollateral(mp, collElepan, HOT, "");
        }
        IMorphoB(MORPHO).borrow(mp, borrowUsdc, 0, HOT, LANDING);
        vm.stopBroadcast();

        require(IERC20B(USDC).balanceOf(LANDING) >= landBefore + borrowUsdc, "LANDING_MISS");
        console2.log("idle", idle);
        console2.log("borrowed", borrowUsdc);
        console2.log("landingUsdc", IERC20B(USDC).balanceOf(LANDING));
        console2.log("BORROW_TO_LANDING_OK", uint256(1));
    }
}
