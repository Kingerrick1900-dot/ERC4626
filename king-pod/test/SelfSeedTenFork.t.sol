// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownFixedOracle} from "../src/CrownFixedOracle.sol";
import {CrownSelfSeedTen} from "../src/CrownSelfSeedTen.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

contract SelfSeedTenForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;
    uint256 constant PRICE_10 = 1e35;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
    }

    function test_self_seed_ten_arms_book() public {
        uint256 seed = 700_000e6;
        uint256 usdc0 = IERC20(USDC).balanceOf(HOT);
        uint256 ele0 = IERC20(ELE).balanceOf(HOT);
        assertGt(ele0, 1e8);

        vm.startPrank(HOT);
        CrownFixedOracle oracle = new CrownFixedOracle(PRICE_10);
        IMorpho.MarketParams memory mp =
            IMorpho.MarketParams(USDC, ELE, address(oracle), IRM, LLTV_915);
        IMorpho(MORPHO).createMarket(mp);
        bytes32 id = keccak256(abi.encode(mp));

        CrownSelfSeedTen h = new CrownSelfSeedTen(HOT, address(oracle));
        IMorpho(MORPHO).setAuthorization(address(h), true);
        IERC20(ELE).approve(address(h), ele0);
        h.selfSeed(ele0, seed);
        vm.stopPrank();

        (uint128 sa,, uint128 ba,,,) = IMorpho(MORPHO).market(id);
        (, uint128 bor, uint128 coll) = IMorpho(MORPHO).position(id, HOT);
        console2.log("sa", uint256(sa));
        console2.log("ba", uint256(ba));
        console2.log("coll", uint256(coll));
        console2.log("borShares", uint256(bor));
        console2.log("usdcDelta", int256(IERC20(USDC).balanceOf(HOT)) - int256(usdc0));

        assertEq(uint256(coll), ele0, "ele posted");
        assertApproxEqAbs(uint256(sa), seed, 1e6);
        assertApproxEqAbs(uint256(ba), seed, 1e6);
        assertApproxEqAbs(IERC20(USDC).balanceOf(HOT), usdc0, 1e6);
        assertEq(IERC20(ELE).balanceOf(HOT), 0);
    }
}
