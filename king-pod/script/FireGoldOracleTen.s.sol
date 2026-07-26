// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFixedOracle} from "../src/CrownFixedOracle.sol";
import {CrownGold} from "../src/CrownGold.sol";
import {CrownSelfSeedGold} from "../src/CrownSelfSeedGold.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoF {
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

/// @notice KING_GO=1 FIRE_GOLD_ORACLE_TEN=1 — kXAU/USDC Morpho @ $10 oracle + min self-seed
/// @dev kXAU 8dp. PRICE_10 = 1e35 (same scale as TEN ELE). Default seed $1 USDC.
contract FireGoldOracleTen is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;
    /// @dev Morpho scale $10 per 1e8 kXAU → 1e35
    uint256 constant PRICE_10 = 1e35;
    uint256 constant DEFAULT_SEED = 1e6; // $1 — minimum to open the book
    /// @dev At $10 / 91.5% LLTV, $1 borrow needs ~0.11 kXAU; mint 1.0 for buffer
    uint256 constant DEFAULT_MINT = 1e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_GOLD_ORACLE_TEN", uint256(0)) == 1, "NEED FIRE_GOLD_ORACLE_TEN=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IMorphoF(MORPHO).isLltvEnabled(LLTV_915), "LLTV");

        uint256 seed = vm.envOr("SEED_USDC", DEFAULT_SEED);
        uint256 mintAmt = vm.envOr("GOLD_MINT", DEFAULT_MINT);

        console2.log("hotUsdcBefore", IERC20F(USDC).balanceOf(HOT));
        console2.log("seed", seed);
        console2.log("oraclePriceScale", PRICE_10);

        vm.startBroadcast(pk);

        CrownGold gold = new CrownGold(HOT);
        console2.log("gold", address(gold));

        CrownFixedOracle oracle = new CrownFixedOracle(PRICE_10);
        console2.log("oracle", address(oracle));
        console2.log("oraclePrice", oracle.price());
        require(oracle.price() == PRICE_10, "ORACLE_NOT_10");

        IMorphoF.MarketParams memory mp = IMorphoF.MarketParams({
            loanToken: USDC,
            collateralToken: address(gold),
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV_915
        });
        bytes32 id = keccak256(abi.encode(mp));
        (address loan,,,,) = IMorphoF(MORPHO).idToMarketParams(id);
        if (loan == address(0)) {
            IMorphoF(MORPHO).createMarket(mp);
            console2.log("createdMarket");
        } else {
            console2.log("marketExists");
        }
        console2.logBytes32(id);

        gold.mint(HOT, mintAmt);
        console2.log("mintedGold", mintAmt);

        CrownSelfSeedGold helper = new CrownSelfSeedGold(HOT, address(gold), address(oracle));
        console2.log("helper", address(helper));

        IMorphoF(MORPHO).setAuthorization(address(helper), true);
        IERC20F(address(gold)).approve(address(helper), mintAmt);
        helper.selfSeed(mintAmt, seed);

        vm.stopBroadcast();

        (uint128 sa,, uint128 ba,,,) = IMorphoF(MORPHO).market(id);
        (uint256 supShares, uint128 borShares, uint128 coll) = IMorphoF(MORPHO).position(id, HOT);
        console2.log("marketSupply", uint256(sa));
        console2.log("marketBorrow", uint256(ba));
        console2.log("kingSupplyShares", supShares);
        console2.log("kingBorrowShares", uint256(borShares));
        console2.log("kingColl", uint256(coll));
        console2.log("hotUsdcAfter", IERC20F(USDC).balanceOf(HOT));
        console2.log("hotGoldAfter", IERC20F(address(gold)).balanceOf(HOT));
        console2.log("GOLD_ORACLE_TEN_OK", uint256(1));
    }
}
