// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ISafeProxyFactory {
    function createProxyWithNonce(address singleton, bytes memory initializer, uint256 saltNonce)
        external
        returns (address proxy);
}

interface ISafeSetup {
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
}

interface ISafeView {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
}

/// @notice Deploy Kingdom 2-of-3 Safe on Base. FIRE_KINGDOM_SAFE=1
/// @dev Owners are public addresses only — no private keys required for deploy.
///      Deployer pays gas (HOT by default). Safe owns itself after setup.
contract FireKingdomSafe is Script {
    // Safe 1.4.1 (canonical) on Base
    address constant FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address constant SINGLETON_L2 = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
    address constant FALLBACK_HANDLER = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;

    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant BACKUP = 0x898DbAFfCD37298a60Fd306e5D1B24fE16C12507;
    address constant SIGNER3 = 0x5E07D7167282F9ec912a05c3048D7D0F24A8b826; // gas wallet / third signer
    uint256 constant THRESHOLD = 2;

    function run() external {
        require(vm.envOr("FIRE_KINGDOM_SAFE", uint256(0)) == 1, "FIRE_KINGDOM_SAFE");
        uint256 pk = vm.envUint("HOT_KEY");

        address[] memory owners = new address[](3);
        owners[0] = LANDING;
        owners[1] = BACKUP;
        owners[2] = SIGNER3;

        bytes memory initializer = abi.encodeCall(
            ISafeSetup.setup,
            (owners, THRESHOLD, address(0), bytes(""), FALLBACK_HANDLER, address(0), 0, payable(address(0)))
        );

        uint256 salt = vm.envOr("SAFE_SALT", uint256(uint256(keccak256("KINGDOM_SAFE_2OF3_V1"))));

        console2.log("factory", FACTORY);
        console2.log("singleton", SINGLETON_L2);
        console2.log("threshold", THRESHOLD);
        console2.log("owner0", owners[0]);
        console2.log("owner1", owners[1]);
        console2.log("owner2", owners[2]);
        console2.log("salt", salt);

        vm.startBroadcast(pk);
        address safe = ISafeProxyFactory(FACTORY).createProxyWithNonce(SINGLETON_L2, initializer, salt);
        vm.stopBroadcast();

        address[] memory got = ISafeView(safe).getOwners();
        uint256 th = ISafeView(safe).getThreshold();
        require(th == THRESHOLD, "THRESHOLD");
        require(got.length == 3, "OWNERS");

        console2.log("KingdomSafe", safe);
        console2.log("liveThreshold", th);
        console2.log("KINGDOM_SAFE_DEPLOYED", uint256(1));
    }
}
