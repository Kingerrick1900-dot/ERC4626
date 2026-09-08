// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownVaultSolver} from "../src/CrownVaultSolver.sol";

interface IMorphoFork {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Base fork: deploy solver, seed $1 live USDC, peel 20¢ to Landing.
contract CrownVaultSolverForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant EUSD_MARKET = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;

    function test_fork_willFromZero_live_dust() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
        vm.createSelectFork(rpc);

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoFork(MORPHO).idToMarketParams(EUSD_MARKET);
        assertEq(loan, USDC);
        assertEq(coll, EUSD);
        assertEq(irm, IRM);

        uint256 seed = IERC20F(USDC).balanceOf(HOT);
        assertGe(seed, 1e6); // ≥ $1 live dust

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        CrownVaultSolver solver = new CrownVaultSolver(MORPHO, USDC, EUSD, GUSD, HOT, LANDING, HOT);
        solver.setEusdMarket(oracle, IRM, lltv, EUSD_MARKET);
        solver.setPeelBps(2_000);
        IMorphoFork(MORPHO).setAuthorization(address(solver), true);

        IERC20F(USDC).approve(address(solver), seed);
        // coll already posted on live book for HOT — pass 0 extra
        (uint256 peeled, uint256 kept) = solver.willFromZero(seed, 0, 0, 0);
        vm.stopPrank();

        assertEq(peeled, (seed * 2_000) / 10_000);
        assertEq(kept, seed - peeled);
        assertEq(IERC20F(USDC).balanceOf(LANDING), landBefore + peeled);
        assertEq(solver.idleEusd(), kept);

        console2.log("solver", address(solver));
        console2.log("seed", seed);
        console2.log("peeled", peeled);
        console2.log("kept", kept);
        console2.log("landingDelta", peeled);
    }
}
