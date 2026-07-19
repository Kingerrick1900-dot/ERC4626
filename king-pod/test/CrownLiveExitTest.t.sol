// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLiveExitTest} from "../src/CrownLiveExitTest.sol";

interface IERC20T {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IVaultV2T {
    function submit(bytes calldata data) external;
    function setForceDeallocatePenalty(address adapter, uint256 penalty) external;
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
    function curator() external view returns (address);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32) external view returns (MarketParams memory);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

contract CrownLiveExitTestFork is Test {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://base-mainnet.public.blastapi.io")));
    }

    function test_GasOnlyLiveExitPath() public {
        uint256 assets = 100e6;
        IMorphoT.MarketParams memory m = IMorphoT(MORPHO).idToMarketParams(MARKET_ID);
        uint256 rssBefore = IERC20T(RSS).balanceOf(HOT);

        vm.startPrank(HOT);
        IVaultV2T(VAULT).submit(abi.encodeCall(IVaultV2T.setForceDeallocatePenalty, (ADAPTER, 0)));
        IVaultV2T(VAULT).setForceDeallocatePenalty(ADAPTER, 0);

        CrownLiveExitTest freer = new CrownLiveExitTest(
            MORPHO, USDC, RSS, VAULT, ADAPTER, HOT, MARKET_ID,
            m.loanToken, m.collateralToken, m.oracle, m.irm, m.lltv
        );
        IERC20T(RSS).approve(address(freer), type(uint256).max);
        freer.run(assets);

        IVaultV2T(VAULT).submit(abi.encodeCall(IVaultV2T.setForceDeallocatePenalty, (ADAPTER, 0.01e18)));
        IVaultV2T(VAULT).setForceDeallocatePenalty(ADAPTER, 0.01e18);
        vm.stopPrank();

        assertTrue(freer.done());
        assertEq(freer.provenAssets(), assets);
        assertEq(IVaultV2T(VAULT).forceDeallocatePenalty(ADAPTER), 0.01e18);
        assertEq(IERC20T(RSS).balanceOf(HOT), rssBefore);
        (uint256 ss, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(MARKET_ID, address(freer));
        assertEq(ss, 0);
        assertEq(uint256(bor), 0);
        assertEq(uint256(coll), 0);
        console2.log("PASS gas-only live exit path", assets);
    }
}
