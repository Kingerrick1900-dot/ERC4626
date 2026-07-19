// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLiveExitTest} from "../src/CrownLiveExitTest.sol";

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IVaultV2S {
    function submit(bytes calldata data) external;
    function setForceDeallocatePenalty(address adapter, uint256 penalty) external;
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface IMorphoS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Live gas-only forceDeallocate proof. King: proceed to last tests.
/// @dev Env: PRIVATE_KEY (hot). Optional TEST_ASSETS (default 100e6 = $100).
contract FireLiveExitTest is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant PENALTY_1PCT = 0.01e18;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "signer must be hot");

        uint256 assets = vm.envOr("TEST_ASSETS", uint256(100e6));
        IMorphoS.MarketParams memory m = IMorphoS(MORPHO).idToMarketParams(MARKET_ID);

        uint256 rssBefore = IERC20S(RSS).balanceOf(HOT);

        vm.startBroadcast(pk);

        IVaultV2S(VAULT).submit(abi.encodeCall(IVaultV2S.setForceDeallocatePenalty, (ADAPTER, 0)));
        IVaultV2S(VAULT).setForceDeallocatePenalty(ADAPTER, 0);

        CrownLiveExitTest freer = new CrownLiveExitTest(
            MORPHO,
            USDC,
            RSS,
            VAULT,
            ADAPTER,
            HOT,
            MARKET_ID,
            m.loanToken,
            m.collateralToken,
            m.oracle,
            m.irm,
            m.lltv
        );

        IERC20S(RSS).approve(address(freer), type(uint256).max);
        freer.run(assets);

        IVaultV2S(VAULT).submit(abi.encodeCall(IVaultV2S.setForceDeallocatePenalty, (ADAPTER, PENALTY_1PCT)));
        IVaultV2S(VAULT).setForceDeallocatePenalty(ADAPTER, PENALTY_1PCT);

        vm.stopBroadcast();

        require(freer.done(), "not done");
        require(IVaultV2S(VAULT).forceDeallocatePenalty(ADAPTER) == PENALTY_1PCT, "penalty");
        (uint256 ss, uint128 bor, uint128 coll) = IMorphoS(MORPHO).position(MARKET_ID, address(freer));
        require(ss == 0 && bor == 0 && coll == 0, "freer morpho dirty");

        console2.log("LIVE_EXIT_PROVEN", assets);
        console2.log("freer", address(freer));
        console2.log("rssBefore", rssBefore);
        console2.log("rssAfter", IERC20S(RSS).balanceOf(HOT));
        console2.log("penalty", IVaultV2S(VAULT).forceDeallocatePenalty(ADAPTER));
        console2.log("vaultTotalAssets", IVaultV2S(VAULT).totalAssets());
        (uint128 sup,, uint128 b,,,) = IMorphoS(MORPHO).market(MARKET_ID);
        console2.log("marketSupply", uint256(sup));
        console2.log("marketBorrow", uint256(b));
    }
}
