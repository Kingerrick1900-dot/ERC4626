// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoP {
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

    function position(bytes32 id, address user)
        external
        view
        returns (uint256, uint128, uint128);

    function withdrawCollateral(MarketParams calldata, uint256 assets, address onBehalf, address receiver) external;
}

interface IOracleP {
    function price() external view returns (uint256);
}

/// @notice Free Elepan from Morpho. Borrow stays. Fork-proven at 20M+.
/// @dev KING_GO=1 FIRE_MORPHO_PULL=1
contract FireMorphoPullElepan is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    uint256 constant SAFE_LTV = 700000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MORPHO_PULL", uint256(0)) == 1, "NEED FIRE_MORPHO_PULL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorphoP.MarketParams memory mp = IMorphoP.MarketParams({
            loanToken: USDC,
            collateralToken: ELEPAN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (, uint128 borrowShares, uint128 coll) = IMorphoP(MORPHO).position(ELE_USDC, HOT);
        (, , uint128 borrowA, uint128 totalBorrowShares,,) = IMorphoP(MORPHO).market(ELE_USDC);
        uint256 borrowAssets =
            totalBorrowShares == 0 ? 0 : uint256(borrowShares) * uint256(borrowA) / uint256(totalBorrowShares);

        uint256 price = IOracleP(ORACLE).price();
        uint256 minCollVal = borrowAssets * 1e18 / SAFE_LTV;
        uint256 minColl = minCollVal * 1e36 / price;
        require(uint256(coll) > minColl, "NO_FREE_COLL");
        uint256 maxPull = uint256(coll) - minColl;

        uint256 pull = vm.envOr("PULL_ELEPAN", maxPull);
        require(pull > 0 && pull <= maxPull, "PULL_SIZE");

        uint256 before = IERC20P(ELEPAN).balanceOf(HOT);
        vm.startBroadcast(pk);
        IMorphoP(MORPHO).withdrawCollateral(mp, pull, HOT, HOT);
        vm.stopBroadcast();

        console2.log("pulledElepan", pull);
        console2.log("maxPullAt70Ltv", maxPull);
        console2.log("borrowUsdcKept", borrowAssets);
        console2.log("hotElepan", IERC20P(ELEPAN).balanceOf(HOT));
        console2.log("MORPHO_PULL_OK", IERC20P(ELEPAN).balanceOf(HOT) >= before + pull ? uint256(1) : uint256(0));
    }
}
