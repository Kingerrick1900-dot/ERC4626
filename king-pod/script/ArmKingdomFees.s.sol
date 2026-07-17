// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ICrownRouterFee {
    function setTreasury(address t) external;
    function setFeeBps(uint256 bps) external;
    function treasury() external view returns (address);
    function feeBps() external view returns (uint256);
}

interface IMetaMorphoFee {
    function setFeeRecipient(address newFeeRecipient) external;
    function setFee(uint256 newFee) external;
    function feeRecipient() external view returns (address);
    function fee() external view returns (uint256);
}

/// @notice Point every live fee rail at KingVault and arm rates.
/// Router: Morpho 0% wholesale → Crown charges feeBps on every flash (paid by callers).
/// yRSS: performance fee on vault interest → KingVault.
contract ArmKingdomFees is Script {
    address constant ROUTER = 0x13734BffdDFf6CbDE474B3F5467d86e813232577;
    address constant YVAULT = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;

    // 30 bps = 0.30% per flash (contract max 100 bps)
    uint256 constant ROUTER_FEE_BPS = 30;
    // Keep 10% performance fee on yRSS (1e17 = 10% of 1e18)
    uint256 constant YRSS_PERF_FEE = 0.1e18;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        console2.log("routerTreasuryBefore", ICrownRouterFee(ROUTER).treasury());
        console2.log("routerFeeBefore", ICrownRouterFee(ROUTER).feeBps());
        console2.log("yRssRecipientBefore", IMetaMorphoFee(YVAULT).feeRecipient());
        console2.log("yRssFeeBefore", IMetaMorphoFee(YVAULT).fee());

        vm.startBroadcast(pk);

        ICrownRouterFee(ROUTER).setTreasury(KING_VAULT);
        ICrownRouterFee(ROUTER).setFeeBps(ROUTER_FEE_BPS);

        IMetaMorphoFee(YVAULT).setFeeRecipient(KING_VAULT);
        IMetaMorphoFee(YVAULT).setFee(YRSS_PERF_FEE);

        vm.stopBroadcast();

        console2.log("routerTreasuryAfter", ICrownRouterFee(ROUTER).treasury());
        console2.log("routerFeeAfter", ICrownRouterFee(ROUTER).feeBps());
        console2.log("yRssRecipientAfter", IMetaMorphoFee(YVAULT).feeRecipient());
        console2.log("yRssFeeAfter", IMetaMorphoFee(YVAULT).fee());
    }
}
