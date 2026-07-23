// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256);
    function reallocate(MarketAllocation[] calldata allocations) external;
    function totalAssets() external view returns (uint256);
}

interface IMorphoView {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @notice Seed Elepan/USDC moat with $2 via yELEPAN-USDC (deposit + reallocate).
/// @dev Leaves ≥ $1 USDC on hot. King GO: KING_GO=1 FIRE_MOAT_SEED=1.
contract SeedElepanMoatTwoUsdc is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELEPAN = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000; // 77%
    bytes32 constant MARKET =
        0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    uint256 constant TWO_USDC = 2e6;
    uint256 constant FLOOR = 1e6; // leave ≥ $1 on hot

    function run() external {
        require(vm.envUint("KING_GO") == 1, "no KING_GO");
        require(vm.envUint("FIRE_MOAT_SEED") == 1, "no FIRE_MOAT_SEED");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        require(me == HOT, "not hot key");

        uint256 hotBal = IERC20(USDC).balanceOf(me);
        console2.log("hotUsdcBefore", hotBal);
        require(hotBal >= TWO_USDC + FLOOR, "NEED_3_USDC_KEEP_FLOOR");

        (uint128 supBefore,,,,,) = IMorphoView(MORPHO).market(MARKET);
        console2.log("moatSupplyBefore", uint256(supBefore));

        IMetaMorpho.MarketParams memory mp = IMetaMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: ELEPAN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        vm.startBroadcast(pk);
        IERC20(USDC).approve(YELEPAN, TWO_USDC);
        uint256 shares = IMetaMorpho(YELEPAN).deposit(TWO_USDC, me);

        // Ensure idle hits the moat (deposit usually supplies via queue; this sweeps remainder).
        IMetaMorpho.MarketAllocation[] memory allocs = new IMetaMorpho.MarketAllocation[](1);
        allocs[0] = IMetaMorpho.MarketAllocation({marketParams: mp, assets: type(uint256).max});
        IMetaMorpho(YELEPAN).reallocate(allocs);
        vm.stopBroadcast();

        (uint128 supAfter,,,,,) = IMorphoView(MORPHO).market(MARKET);
        (uint256 vaultShares,,) = IMorphoView(MORPHO).position(MARKET, YELEPAN);
        console2.log("depositShares", shares);
        console2.log("moatSupplyAfter", uint256(supAfter));
        console2.log("vaultMorphoShares", vaultShares);
        console2.log("yELEPAN_totalAssets", IMetaMorpho(YELEPAN).totalAssets());
        console2.log("hotUsdcAfter", IERC20(USDC).balanceOf(me));
        require(IERC20(USDC).balanceOf(me) >= FLOOR, "FLOOR_HOT");
        require(uint256(supAfter) >= uint256(supBefore) + TWO_USDC - 1, "MOAT_NOT_SEEDED");
        console2.log("MOAT_SEED_OK", uint256(1));
    }
}
