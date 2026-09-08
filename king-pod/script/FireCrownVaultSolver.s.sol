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

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy CrownVaultSolver against LIVE Base eUSD market. Minimal gas. No willFromZero.
/// @dev KING_GO=1 forge script script/FireCrownVaultSolver.s.sol:FireCrownVaultSolverDeploy --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireCrownVaultSolverDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    /// @dev Live eUSD/USDC Morpho book (40M coll already posted on HOT).
    bytes32 constant EUSD_MARKET_LIVE = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;
    address constant CREDIT_LIVE = 0x5568fE662363d7F3fa52349A99C9e19C6616B60d;
    uint256 constant LLTV = 860000000000000000; // 86%

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(pk);
        require(signer == HOT, "NOT_HOT");

        // Read live eUSD market — must already exist
        (address loan, address coll, address eusdOracle, address irm, uint256 lltv) =
            IMorphoVS(MORPHO).idToMarketParams(EUSD_MARKET_LIVE);
        require(loan == USDC && coll == EUSD, "EUSD_MKT");
        require(eusdOracle != address(0) && irm == IRM, "EUSD_ORACLE");

        vm.startBroadcast(pk);

        CrownVaultSolver solver = new CrownVaultSolver(MORPHO, USDC, EUSD, GUSD, HOT, LANDING, HOT);
        solver.setEusdMarket(eusdOracle, IRM, lltv == 0 ? LLTV : lltv, EUSD_MARKET_LIVE);

        // Optional gUSD book — create only if CREATE_GUSD_MKT=1 (extra gas)
        bytes32 gusdId;
        if (vm.envOr("CREATE_GUSD_MKT", uint256(0)) == 1) {
            MorphoFixedOracle gOracle = new MorphoFixedOracle(1e24);
            IMorphoVS.MarketParams memory gmp = IMorphoVS.MarketParams(USDC, GUSD, address(gOracle), IRM, LLTV);
            try IMorphoVS(MORPHO).createMarket(gmp) {} catch {}
            gusdId = keccak256(abi.encode(gmp));
            solver.setGusdMarket(address(gOracle), IRM, LLTV, gusdId);
            console2.log("gusdOracle", address(gOracle));
            console2.logBytes32(gusdId);
        }

        solver.setPeelBps(2_000);
        solver.setArmed(true);
        IMorphoVS(MORPHO).setAuthorization(address(solver), true);

        address credit = vm.envOr("CREDIT", CREDIT_LIVE);
        // Probe credit has code before wiring
        if (credit != address(0) && credit.code.length > 0) {
            solver.setCredit(credit);
        }

        vm.stopBroadcast();

        console2.log("CrownVaultSolver", address(solver));
        console2.log("eusdOracle", eusdOracle);
        console2.logBytes32(EUSD_MARKET_LIVE);
        console2.log("credit", credit);
        console2.log("HOT_USDC", IERC20A(USDC).balanceOf(HOT));
        console2.log("HOT_ETH_wei", HOT.balance);
    }
}

/// @notice Fire willFromZero — requires real USDC seed on HOT. No flash.
/// @dev KING_GO=1 FIRE_WILL=1 SEED_USDC=… VAULT_SOLVER=0x… forge script …:FireWillFromZero --broadcast --slow
contract FireWillFromZero is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_WILL", uint256(0)) == 1, "NO_FIRE");
        address solverAddr = vm.envAddress("VAULT_SOLVER");
        uint256 seed = vm.envUint("SEED_USDC"); // 6dp
        uint256 eusdColl = vm.envOr("EUSD_COLL", uint256(0));
        uint256 gusdColl = vm.envOr("GUSD_COLL", uint256(0));
        uint256 ask = vm.envOr("BORROW_ASK", uint256(0));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(seed > 0, "NO_SEED");
        require(IERC20A(USDC).balanceOf(HOT) >= seed, "USDC_SHORT");

        CrownVaultSolver solver = CrownVaultSolver(solverAddr);
        vm.startBroadcast(pk);
        IERC20A(USDC).approve(solverAddr, seed);
        if (eusdColl > 0) IERC20A(EUSD).approve(solverAddr, eusdColl);
        if (gusdColl > 0) IERC20A(GUSD).approve(solverAddr, gusdColl);
        (uint256 peeled, uint256 kept) = solver.willFromZero(seed, eusdColl, gusdColl, ask);
        vm.stopBroadcast();

        console2.log("peeled", peeled);
        console2.log("kept", kept);
        console2.log("landing", IERC20A(USDC).balanceOf(LANDING));
        (bool armed,, uint256 idle,,, uint256 totPeel, uint256 totKept, uint256 land) = solver.book();
        console2.log("armed", armed);
        console2.log("idle", idle);
        console2.log("totalPeeled", totPeel);
        console2.log("totalKept", totKept);
        console2.log("landingBook", land);
    }
}
