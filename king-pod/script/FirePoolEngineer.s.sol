// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPoolEngineer} from "../src/CrownPoolEngineer.sol";

interface IEusdMinter {
    function setMinter(address, bool) external;
}

interface IVaultAdmin {
    function setTarget(address target, bool on) external;
}

/// @notice Deploy CrownPoolEngineer, grant eUSD minter, arm KingAgent vault.
contract FirePoolEngineer is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant AGENT = 0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA;
    address constant VAULT = 0xc3f2ACe4161B82dbceE08Ea636467D2C3bD72458;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        vm.startBroadcast(pk);

        CrownPoolEngineer eng = new CrownPoolEngineer(YRSS, EUSD, USDC, RSS, NPM, HOT, ATTEST, HOT);
        eng.setAgent(AGENT);
        eng.setOperator(AGENT, true);
        eng.setOperator(VAULT, true);
        IEusdMinter(EUSD).setMinter(address(eng), true);
        IVaultAdmin(VAULT).setTarget(address(eng), true);

        vm.stopBroadcast();
        console2.log("CrownPoolEngineer", address(eng));
        console2.log("totalUsdcSeeded", eng.totalUsdcSeeded());
    }
}
