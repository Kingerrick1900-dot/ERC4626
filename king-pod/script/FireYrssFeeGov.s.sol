// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IYrssFeeGov {
    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function guardian() external view returns (address);
    function timelock() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function setFee(uint256 newFee) external;
    function setFeeRecipient(address newFeeRecipient) external;
    function submitGuardian(address newGuardian) external;
    function acceptGuardian() external;
    function submitTimelock(uint256 newTimelock) external;
    function acceptTimelock() external;
}

interface IPublicAllocatorFG {
    function fee(address vault) external view returns (uint256);
    function admin(address vault) external view returns (address);
    function setFee(address vault, uint256 newFee) external;
}

/// @notice FEES / GOV controls for yRSS. Default = status only.
/// @dev KING_GO=1 required. FIRE_FEE=1 to apply changes.
///      NEW_FEE_WAD default keeps 10% (1e17). FEE_RECIPIENT / GUARDIAN / TIMELOCK optional env.
contract FireYrssFeeGov is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: KING_GO=1");

        bool doFire = vm.envOr("FIRE_FEE", uint256(0)) == 1;
        uint256 newFee = vm.envOr("NEW_FEE_WAD", uint256(1e17)); // 10%
        address newRecipient = vm.envOr("FEE_RECIPIENT", HOT);
        address newGuardian = vm.envOr("GUARDIAN", address(0));
        uint256 newTimelock = vm.envOr("TIMELOCK", uint256(0));
        uint256 newPaFee = vm.envOr("PA_FEE_WEI", uint256(0));

        console2.log("=== FEES YIELD GOV STATUS ===");
        console2.log("fee", uint256(IYrssFeeGov(YRSS).fee()));
        console2.log("feeRecipient", IYrssFeeGov(YRSS).feeRecipient());
        console2.log("owner", IYrssFeeGov(YRSS).owner());
        console2.log("curator", IYrssFeeGov(YRSS).curator());
        console2.log("guardian", IYrssFeeGov(YRSS).guardian());
        console2.log("timelock", IYrssFeeGov(YRSS).timelock());
        console2.log("totalAssets", IYrssFeeGov(YRSS).totalAssets());
        console2.log("paFee", IPublicAllocatorFG(PA).fee(YRSS));
        console2.log("paAdmin", IPublicAllocatorFG(PA).admin(YRSS));
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        require(newFee <= 0.25e18, "FEE_CAP_25pct"); // MetaMorpho-style sanity

        if (!doFire) {
            console2.log("PREFLIGHT - set FIRE_FEE=1 to apply");
            console2.log("READY", uint256(0));
            return;
        }

        vm.startBroadcast(pk);
        if (newFee != uint256(IYrssFeeGov(YRSS).fee())) {
            IYrssFeeGov(YRSS).setFee(newFee);
        }
        if (newRecipient != IYrssFeeGov(YRSS).feeRecipient()) {
            IYrssFeeGov(YRSS).setFeeRecipient(newRecipient);
        }
        if (newGuardian != address(0) && newGuardian != IYrssFeeGov(YRSS).guardian()) {
            IYrssFeeGov(YRSS).submitGuardian(newGuardian);
            // accept may need timelock 0 path / second call - log for King
            console2.log("submittedGuardian", newGuardian);
        }
        if (newTimelock != IYrssFeeGov(YRSS).timelock() && newTimelock > 0) {
            IYrssFeeGov(YRSS).submitTimelock(newTimelock);
            console2.log("submittedTimelock", newTimelock);
        }
        if (newPaFee != IPublicAllocatorFG(PA).fee(YRSS)) {
            IPublicAllocatorFG(PA).setFee(YRSS, newPaFee);
        }
        vm.stopBroadcast();

        console2.log("feeAfter", uint256(IYrssFeeGov(YRSS).fee()));
        console2.log("feeRecipientAfter", IYrssFeeGov(YRSS).feeRecipient());
        console2.log("READY", uint256(1));
    }
}
