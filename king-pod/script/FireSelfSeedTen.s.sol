// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFixedOracle} from "../src/CrownFixedOracle.sol";
import {CrownSelfSeedTen} from "../src/CrownSelfSeedTen.sol";

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

    function createMarket(MarketParams memory) external;
    function idToMarketParams(bytes32)
        external
        view
        returns (address, address, address, address, uint256);
    function isLltvEnabled(uint256) external view returns (bool);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

/// @notice KING_GO=1 FIRE_SELF_SEED_TEN=1 — $10 oracle market + flash self-seed
/// @dev ELE 8dp. Default seed $700k. Wallet USDC Δ ≈ 0; king holds coll+supply+debt.
contract FireSelfSeedTen is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;
    /// @dev Morpho scale $10 ELE → 1e35 (not 1e18)
    uint256 constant PRICE_10 = 1e35;
    uint256 constant DEFAULT_SEED = 700_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SELF_SEED_TEN", uint256(0)) == 1, "NEED FIRE_SELF_SEED_TEN=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IMorphoS(MORPHO).isLltvEnabled(LLTV_915), "LLTV");

        uint256 seed = vm.envOr("SEED_USDC", DEFAULT_SEED);
        uint256 eleAmt = vm.envOr("ELE_AMT", uint256(0)); // 0 = all free ELE

        console2.log("hotUsdcBefore", IERC20S(USDC).balanceOf(HOT));
        console2.log("hotEleBefore", IERC20S(ELE).balanceOf(HOT));
        console2.log("seed", seed);

        vm.startBroadcast(pk);

        CrownFixedOracle oracle = new CrownFixedOracle(PRICE_10);
        console2.log("oracle", address(oracle));
        console2.log("oraclePrice", oracle.price());

        IMorphoS.MarketParams memory mp = IMorphoS.MarketParams({
            loanToken: USDC,
            collateralToken: ELE,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV_915
        });
        bytes32 id = keccak256(abi.encode(mp));
        (address loan,,,,) = IMorphoS(MORPHO).idToMarketParams(id);
        if (loan == address(0)) {
            IMorphoS(MORPHO).createMarket(mp);
            console2.log("createdMarket");
        } else {
            console2.log("marketExists");
        }
        console2.logBytes32(id);

        CrownSelfSeedTen helper = new CrownSelfSeedTen(HOT, address(oracle));
        console2.log("helper", address(helper));

        // Allow helper to borrow on behalf of hot
        IMorphoS(MORPHO).setAuthorization(address(helper), true);

        uint256 eleBal = IERC20S(ELE).balanceOf(HOT);
        if (eleAmt == 0 || eleAmt > eleBal) eleAmt = eleBal;
        require(eleAmt >= 1e8, "NEED_ELE");
        IERC20S(ELE).approve(address(helper), eleAmt);
        helper.selfSeed(eleAmt, seed);

        vm.stopBroadcast();

        (uint128 sa,, uint128 ba,,,) = IMorphoS(MORPHO).market(id);
        (uint256 supShares, uint128 borShares, uint128 coll) = IMorphoS(MORPHO).position(id, HOT);
        console2.log("marketSupply", uint256(sa));
        console2.log("marketBorrow", uint256(ba));
        console2.log("kingSupplyShares", supShares);
        console2.log("kingBorrowShares", uint256(borShares));
        console2.log("kingColl", uint256(coll));
        console2.log("hotUsdcAfter", IERC20S(USDC).balanceOf(HOT));
        console2.log("hotEleAfter", IERC20S(ELE).balanceOf(HOT));
        console2.log("SELF_SEED_TEN_OK", uint256(1));
    }
}
