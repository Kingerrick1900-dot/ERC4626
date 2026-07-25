// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYeleS {
    function asset() external view returns (address);
}

/// @notice Surface ELE from Morpho coll → hot. Does NOT deposit into yELE (yELE asset = USDC only).
/// @dev KING_GO=1 FIRE_SURFACE_ELE=1 ELE_AMOUNT=1400000000000000 (14M 8dp default)
contract SupplyEleToVault is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant DEFAULT_ELE = 14_000_000e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SURFACE_ELE", uint256(0)) == 1, "NEED FIRE_SURFACE_ELE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address yAsset = IYeleS(YELE).asset();
        console2.log("yeleAsset", yAsset);
        console2.log("yeleTakesUSDC_notELE", yAsset == USDC ? uint256(1) : uint256(0));
        require(yAsset == USDC, "YELE_NOT_USDC");

        uint256 amt = vm.envOr("ELE_AMOUNT", DEFAULT_ELE);
        (, uint128 borShares, uint128 coll) = IMorphoS(MORPHO).position(ELE_USDC, HOT);
        require(uint256(coll) >= amt, "COLL");

        // Soft HF after withdraw: collUSD/debt >= 1.55
        (,, uint128 ba, uint128 bs,,) = IMorphoS(MORPHO).market(ELE_USDC);
        uint256 debt = borShares == 0 || bs == 0
            ? 0
            : (uint256(ba) * uint256(borShares) + uint256(bs) - 1) / uint256(bs);
        uint256 collAfter = uint256(coll) - amt;
        if (debt > 0) {
            uint256 hf = (collAfter * 1e18 * 1e6) / (debt * 1e8);
            console2.log("hfAfterWad", hf);
            require(hf >= 1.55e18, "HF");
        }

        IMorphoS.MarketParams memory mp = IMorphoS.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
        uint256 eleBefore = IERC20S(ELE).balanceOf(HOT);

        vm.startBroadcast(pk);
        IMorphoS(MORPHO).withdrawCollateral(mp, amt, HOT, HOT);
        vm.stopBroadcast();

        console2.log("eleFreed", IERC20S(ELE).balanceOf(HOT) - eleBefore);
        console2.log("NEXT", "Fund yELE with USDC after acceptCap(WETH), then curatorDiskFill");
        console2.log("SURFACE_ELE_OK", uint256(1));
    }
}
