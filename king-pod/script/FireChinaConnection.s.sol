// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {RoyalCard} from "../src/royal/RoyalCard.sol";
import {CrownLakalaAcquiring} from "../src/china/CrownLakalaAcquiring.sol";
import {CrownLakalaCardBridge} from "../src/china/CrownLakalaCardBridge.sol";

/// @notice Phase-4 China Connection fire — Polygon RoyalCard + Lakala-class + merchant wire.
/// @dev Uses existing live PayAdapter / OpenMoney / attest. POLY_KEY must be owner of adapters.
interface IPayAdapter {
    function setMerchant(address m, bool ok) external;
    function owner() external view returns (address);
}

interface IOpenMoney {
    function setMerchant(address m, bool ok) external;
}

contract FireChinaConnection is Script {
    // Polygon live triangle
    address constant POLY_EUSD = 0xd8A639BbD49e02eA590569D548d578e8345baf50;
    address constant POLY_PAY = 0x2FAEd8D83f61d157419b33F7938aDCd9F2c4f629;
    address constant POLY_OPEN = 0xe3e165C8823d35966C85353D5A4f257623417a7c;
    address constant POLY_ATTEST = 0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211;

    function run() external {
        uint256 pk = vm.envUint("POLY_KEY");
        address desk = vm.envOr("CHINA_DESK", vm.addr(pk));
        uint16 mdr = uint16(vm.envOr("MDR_BPS", uint256(100)));

        vm.startBroadcast(pk);

        RoyalCard card = new RoyalCard(POLY_EUSD, vm.addr(pk));
        card.setModules(POLY_PAY, POLY_ATTEST);

        CrownLakalaAcquiring acq = new CrownLakalaAcquiring(POLY_EUSD, vm.addr(pk), mdr);
        CrownLakalaCardBridge bridge = new CrownLakalaCardBridge(vm.addr(pk));
        acq.setModules(POLY_ATTEST, address(bridge), mdr);
        bridge.wire(address(card), address(acq), false);

        bytes32 mercId = keccak256("CHINA-DESK-001");
        bytes32 termNo = keccak256("TERM-SOFTPOS-01");
        acq.registerMerchant(mercId, desk, desk, 0, keccak256("china-kyb"));
        acq.registerTerminal(mercId, termNo, keccak256("softpos-v0"));

        IPayAdapter(POLY_PAY).setMerchant(desk, true);
        IOpenMoney(POLY_OPEN).setMerchant(desk, true);

        // Smoke logical card (no physical SE yet)
        bytes32 cardId = keccak256(abi.encodePacked("CN-SMOKE", desk));
        card.issue(cardId, desk, keccak256("nfc-pubkey-stub"), 1_000 ether);

        vm.stopBroadcast();

        console2.log("RoyalCard", address(card));
        console2.log("CrownLakalaAcquiring", address(acq));
        console2.log("CrownLakalaCardBridge", address(bridge));
        console2.log("ChinaDeskMerchant", desk);
        console2.log("PayAdapter", POLY_PAY);
        console2.log("OpenMoney", POLY_OPEN);
        console2.log("cardId");
        console2.logBytes32(cardId);
        console2.log("mercId");
        console2.logBytes32(mercId);
    }
}
