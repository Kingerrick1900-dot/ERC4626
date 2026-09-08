// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownVaultSolver} from "../src/CrownVaultSolver.sol";
import {MorphoFixedOracle} from "../src/MorphoFixedOracle.sol";

interface IMorphoVS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

/// @notice Deploy CrownVaultSolver + wire eUSD(/gUSD) Morpho markets. No fire.
/// @dev KING_GO=1 forge script script/FireCrownVaultSolver.s.sol:FireCrownVaultSolverDeploy --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireCrownVaultSolverDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    /// @dev Live eUSD/USDC Morpho book from kingdom stack (if already created).
    bytes32 constant EUSD_MARKET_LIVE = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;
    uint256 constant LLTV = 860000000000000000; // 86%

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownVaultSolver solver = new CrownVaultSolver(MORPHO, USDC, EUSD, GUSD, HOT, LANDING, HOT);

        // Prefer live eUSD market; else create with fixed $1 oracle.
        bytes32 eusdId = EUSD_MARKET_LIVE;
        address eusdOracle;
        try IMorphoVS(MORPHO).idToMarketParams(EUSD_MARKET_LIVE) returns (
            address loan, address coll, address oracle, address, uint256
        ) {
            require(loan == USDC && coll == EUSD, "EUSD_MKT");
            eusdOracle = oracle;
        } catch {
            MorphoFixedOracle o = new MorphoFixedOracle(1e24);
            eusdOracle = address(o);
            IMorphoVS.MarketParams memory mp = IMorphoVS.MarketParams(USDC, EUSD, eusdOracle, IRM, LLTV);
            IMorphoVS(MORPHO).createMarket(mp);
            eusdId = keccak256(abi.encode(mp));
        }
        solver.setEusdMarket(eusdOracle, IRM, LLTV, eusdId);

        // Optional gUSD/USDC book (create if missing)
        MorphoFixedOracle gOracle = new MorphoFixedOracle(1e24);
        IMorphoVS.MarketParams memory gmp = IMorphoVS.MarketParams(USDC, GUSD, address(gOracle), IRM, LLTV);
        try IMorphoVS(MORPHO).createMarket(gmp) {} catch {}
        bytes32 gusdId = keccak256(abi.encode(gmp));
        solver.setGusdMarket(address(gOracle), IRM, LLTV, gusdId);

        solver.setPeelBps(2_000); // 20% peel / 80% keep
        solver.setArmed(true);
        IMorphoVS(MORPHO).setAuthorization(address(solver), true);

        // Optional: wire live CrownPrimeCredit if present
        address credit = vm.envOr("CREDIT", address(0));
        if (credit != address(0)) solver.setCredit(credit);

        vm.stopBroadcast();

        console2.log("CrownVaultSolver", address(solver));
        console2.logBytes32(eusdId);
        console2.logBytes32(gusdId);
        console2.log("eusdOracle", eusdOracle);
        console2.log("gusdOracle", address(gOracle));
    }
}

/// @notice Fire willFromZero — requires real USDC seed on HOT. No flash.
/// @dev KING_GO=1 FIRE_WILL=1 SEED_USDC=1000000000000 forge script …:FireWillFromZero --broadcast --slow
contract FireWillFromZero is Script {
    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_WILL", uint256(0)) == 1, "NO_FIRE");
        address solverAddr = vm.envAddress("VAULT_SOLVER");
        uint256 seed = vm.envUint("SEED_USDC"); // 6dp
        uint256 eusdColl = vm.envOr("EUSD_COLL", uint256(0));
        uint256 gusdColl = vm.envOr("GUSD_COLL", uint256(0));
        uint256 ask = vm.envOr("BORROW_ASK", uint256(0));
        uint256 pk = vm.envUint("PRIVATE_KEY");

        CrownVaultSolver solver = CrownVaultSolver(solverAddr);
        vm.startBroadcast(pk);
        (uint256 peeled, uint256 kept) = solver.willFromZero(seed, eusdColl, gusdColl, ask);
        vm.stopBroadcast();

        console2.log("peeled", peeled);
        console2.log("kept", kept);
        (bool armed, uint256 vault, uint256 idle, uint256 supplied, uint256 borrowed, uint256 totPeel,, uint256 land) =
            solver.book();
        console2.log("armed", armed);
        console2.log("vault", vault);
        console2.log("idle", idle);
        console2.log("supplied", supplied);
        console2.log("borrowed", borrowed);
        console2.log("totalPeeled", totPeel);
        console2.log("landing", land);
    }
}
