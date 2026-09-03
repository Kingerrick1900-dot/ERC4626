// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoFixedOracle} from "../src/MorphoFixedOracle.sol";
import {CrownPrimeIdleTap} from "../src/prime/CrownPrimeIdleTap.sol";

interface IMorphoC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function setAuthorization(address authorized, bool newAuthorized) external;
}

interface IMetaMorphoC {
    function submitCap(IMorphoC.MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(IMorphoC.MarketParams memory marketParams) external;
}

interface IPublicAllocatorC {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
}

interface IERC20C {
    function approve(address, uint256) external returns (bool);
}

/// @notice Create eUSD/USDC Morpho book + IdleTap. Does not flash. USDC that lands here gets tapped to credit.
/// @dev KING_GO=1 FIRE_IDLE_TAP=1 forge script …:FireEusdUsdcIdle --broadcast --slow
contract FireEusdUsdcIdle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    uint256 constant LLTV = 860000000000000000; // 86%
    uint256 constant YRSS_CAP = 50_000_000e6;
    uint256 constant POST_EUSD = 20_000_000e18;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_IDLE_TAP", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        MorphoFixedOracle oracle = new MorphoFixedOracle(1e24); // $1
        IMorphoC.MarketParams memory mp = IMorphoC.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoC(MORPHO).createMarket(mp);
        bytes32 id = keccak256(abi.encode(mp));

        CrownPrimeIdleTap tap = new CrownPrimeIdleTap(MORPHO, USDC, EUSD, CREDIT, HOT, HOT);
        tap.setEusdMarket(address(oracle), IRM, LLTV, id);
        IMorphoC(MORPHO).setAuthorization(address(tap), true);

        IMetaMorphoC(YRSS).submitCap(mp, YRSS_CAP);
        IMetaMorphoC(YRSS).acceptCap(mp);

        IPublicAllocatorC.FlowCapsConfig[] memory caps = new IPublicAllocatorC.FlowCapsConfig[](1);
        caps[0] = IPublicAllocatorC.FlowCapsConfig({
            id: id,
            caps: IPublicAllocatorC.FlowCaps({maxIn: uint128(YRSS_CAP), maxOut: uint128(YRSS_CAP)})
        });
        IPublicAllocatorC(PA).setFlowCaps(YRSS, caps);

        IERC20C(EUSD).approve(address(tap), POST_EUSD);
        tap.postEusd(POST_EUSD);

        vm.stopBroadcast();

        console2.log("oracle", address(oracle));
        console2.log("tap", address(tap));
        console2.logBytes32(id);
    }
}
