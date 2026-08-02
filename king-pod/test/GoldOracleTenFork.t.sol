// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownFixedOracle} from "../src/CrownFixedOracle.sol";
import {CrownGold} from "../src/CrownGold.sol";
import {CrownSelfSeedGold} from "../src/CrownSelfSeedGold.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function deal(address, uint256) external; // unused
}

interface IMorphoT {
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

contract GoldOracleTenForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;
    uint256 constant PRICE_10 = 1e35;
    uint256 constant SEED = 1e6;
    uint256 constant MINT = 1e8;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
    }

    function test_goldOracleTen_minSelfSeed() public {
        require(IMorphoT(MORPHO).isLltvEnabled(LLTV_915), "LLTV");

        vm.startPrank(HOT);
        CrownGold gold = new CrownGold(HOT);
        CrownFixedOracle oracle = new CrownFixedOracle(PRICE_10);
        assertEq(oracle.price(), PRICE_10, "oracle must be $10 scale");

        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams({
            loanToken: USDC,
            collateralToken: address(gold),
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV_915
        });
        IMorphoT(MORPHO).createMarket(mp);
        bytes32 id = keccak256(abi.encode(mp));

        gold.mint(HOT, MINT);
        CrownSelfSeedGold helper = new CrownSelfSeedGold(HOT, address(gold), address(oracle));
        IMorphoT(MORPHO).setAuthorization(address(helper), true);
        gold.approve(address(helper), MINT);

        uint256 usdcBefore = IERC20T(USDC).balanceOf(HOT);
        helper.selfSeed(MINT, SEED);
        vm.stopPrank();

        (uint128 sa,, uint128 ba,,,) = IMorphoT(MORPHO).market(id);
        (uint256 sup,, uint128 coll) = IMorphoT(MORPHO).position(id, HOT);

        assertEq(uint256(sa), SEED, "supply");
        assertEq(uint256(ba), SEED, "borrow");
        assertGt(sup, 0, "shares");
        assertEq(uint256(coll), MINT, "coll");
        // matched self-seed: wallet USDC flat (within dust)
        assertApproxEqAbs(IERC20T(USDC).balanceOf(HOT), usdcBefore, 1, "usdc flat");
        console2.log("GOLD_ORACLE_TEN_FORK_OK", uint256(1));
        console2.log("oracle", address(oracle));
        console2.log("gold", address(gold));
        console2.logBytes32(id);
    }
}
