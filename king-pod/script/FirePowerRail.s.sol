// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPowerRail} from "../src/CrownPowerRail.sol";
import {MorphoPegOracle} from "../src/MorphoPegOracle.sol";

interface IEusdFire {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
}

interface IMorphoF {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @dev KING_GO=1 forge script script/FirePowerRail.s.sol:FirePowerRail --rpc-url $BASE_RPC_URL --broadcast --slow
///      CREATE_DOORS=1 MINT_LANDING=<wei> SEED_LOAN=<wei> SEED_ID=<bytes32>
contract FirePowerRail is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address constant USDBC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_86 = 860000000000000000;

    bytes32 constant BOSS = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address existing = vm.envOr("POWER_RAIL", address(0));

        vm.startBroadcast(pk);

        CrownPowerRail rail;
        if (existing == address(0)) {
            rail = new CrownPowerRail(EUSD, MORPHO, HOT, LANDING, HOT);
            if (!IEusdFire(EUSD).isMinter(address(rail))) {
                IEusdFire(EUSD).setMinter(address(rail), true);
            }
            rail.setStable(USDC, true);
            rail.setStable(DAI, true);
            rail.setStable(USDBC, true);
            rail.setStable(EURC, true);
            rail.addHarvestMarket(BOSS);
            console2.log("CrownPowerRail", address(rail));
        } else {
            rail = CrownPowerRail(existing);
            console2.log("USING", existing);
        }

        if (vm.envOr("CREATE_DOORS", uint256(0)) == 1) {
            _eusdLoanDoor(rail, USDC, 1e24, "loan_eUSD_coll_USDC");
            _eusdLoanDoor(rail, DAI, 1e36, "loan_eUSD_coll_DAI");
            _eusdLoanDoor(rail, EURC, 1e24, "loan_eUSD_coll_EURC");
            _eusdCollDoor(rail, USDC, 1e24, "coll_eUSD_loan_USDC");
            _eusdCollDoor(rail, DAI, 1e36, "coll_eUSD_loan_DAI");
            _eusdCollDoor(rail, EURC, 1e24, "coll_eUSD_loan_EURC");
        }

        uint256 mintLanding = vm.envOr("MINT_LANDING", uint256(0));
        if (mintLanding > 0) {
            rail.mintToLanding(mintLanding);
            console2.log("mintToLanding", mintLanding);
        }

        uint256 seedLoan = vm.envOr("SEED_LOAN", uint256(0));
        bytes32 seedId = vm.envOr("SEED_ID", bytes32(0));
        if (seedLoan > 0 && seedId != bytes32(0)) {
            (address loan, address coll, address orc, address irm_, uint256 lltv) =
                IMorphoF(MORPHO).idToMarketParams(seedId);
            require(loan == EUSD, "SEED_NOT_EUSD_LOAN");
            rail.mintSupplyLoan(
                seedId, CrownPowerRail.MarketParams(loan, coll, orc, irm_, lltv), seedLoan
            );
            console2.log("seedLoan", seedLoan);
        }

        vm.stopBroadcast();
        console2.log("isMinter", IEusdFire(EUSD).isMinter(address(rail)));
        console2.log("bossIdle", rail.idleOf(BOSS));
    }

    function _eusdLoanDoor(CrownPowerRail rail, address coll, uint256 peg, string memory tag) internal {
        MorphoPegOracle oracle = new MorphoPegOracle(peg);
        CrownPowerRail.MarketParams memory mp =
            CrownPowerRail.MarketParams(EUSD, coll, address(oracle), IRM, LLTV_86);
        rail.createMarket(mp);
        console2.log(tag);
        console2.logBytes32(keccak256(abi.encode(mp)));
    }

    function _eusdCollDoor(CrownPowerRail rail, address loan, uint256 peg, string memory tag) internal {
        MorphoPegOracle oracle = new MorphoPegOracle(peg);
        CrownPowerRail.MarketParams memory mp =
            CrownPowerRail.MarketParams(loan, EUSD, address(oracle), IRM, LLTV_86);
        rail.createMarket(mp);
        bytes32 id = keccak256(abi.encode(mp));
        rail.addHarvestMarket(id);
        console2.log(tag);
        console2.logBytes32(id);
    }
}
