// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPrimeIdleTap} from "../src/prime/CrownPrimeIdleTap.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {USDCBorrowRouter} from "../src/prime/USDCBorrowRouter.sol";

interface IPublicAllocatorFinish {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;
}

interface IMorphoFinish {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice PA pull yRSS cbBTC idle → eUSD book → IdleTap → credit → draw Landing. Real USDC, no flash.
/// @dev KING_GO=1 FIRE_FINISH_IDLE=1 forge script script/FireFinishIdle.s.sol:FireFinishIdle --broadcast --slow
contract FireFinishIdle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant TAP = 0x23EF8f1D436ec96fd82d5F85D05AF34d8f1b17e5;
    address constant CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;
    address constant ROUTER = 0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    address constant ORACLE_CBBTC = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address constant ORACLE_EUSD = 0x44bc82a9ADaF15edCa1bc0030Bdf7500af5CC750;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_86 = 860000000000000000;

    bytes32 constant CBBTC_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_FINISH_IDLE", uint256(0)) == 1, "NO_FIRE");

        (uint128 supply,, uint128 borrow,,,) = IMorphoFinish(MORPHO).market(CBBTC_ID);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        require(idle > 0, "NO_IDLE");
        uint128 pull = uint128(idle);

        IPublicAllocatorFinish.MarketParams memory cbBtc = IPublicAllocatorFinish.MarketParams({
            loanToken: USDC,
            collateralToken: CBBTC,
            oracle: ORACLE_CBBTC,
            irm: IRM,
            lltv: LLTV_86
        });
        IPublicAllocatorFinish.MarketParams memory eusdMp = IPublicAllocatorFinish.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: ORACLE_EUSD,
            irm: IRM,
            lltv: LLTV_86
        });

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        IPublicAllocatorFinish.Withdrawal[] memory w = new IPublicAllocatorFinish.Withdrawal[](1);
        w[0] = IPublicAllocatorFinish.Withdrawal({marketParams: cbBtc, amount: pull});
        IPublicAllocatorFinish(PA).reallocateTo(YRSS, w, eusdMp);

        uint256 tapped = CrownPrimeIdleTap(TAP).tapEusd(0);
        uint256 idleCredit = CrownPrimeCredit(CREDIT).freeUsdc();

        USDCBorrowRouter(ROUTER).setArmed(true);
        if (idleCredit > 0) {
            USDCBorrowRouter(ROUTER).draw(idleCredit, LANDING);
        }

        vm.stopBroadcast();

        console2.log("pulled", uint256(pull));
        console2.log("tapped", tapped);
        console2.log("creditIdle", CrownPrimeCredit(CREDIT).freeUsdc());
        console2.log("debt", CrownPrimeCredit(CREDIT).debtOf(HOT));
        console2.log("landingUsdc", CrownPrimeCredit(CREDIT).usdc().balanceOf(LANDING));
    }
}
