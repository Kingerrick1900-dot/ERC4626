// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoU {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYrssU {
    function maxWithdraw(address) external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
}

/// @notice Engineer idle into the LIVE RSS/$1200 Morpho book, then pull yRSS liquidity to HOT.
/// @dev Gate: FIRE_IDLE_UNLOCK=1. Uses HOT USDC. Live market 0x41c0… (oracle $1200, 252k RSS coll).
contract FireIdleUnlockYrss is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant MARKET = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        require(vm.envOr("FIRE_IDLE_UNLOCK", uint256(0)) == 1, "FIRE_IDLE_UNLOCK");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 usdcBal = IERC20U(USDC).balanceOf(HOT);
        require(usdcBal > 0, "NO_USDC");

        (uint128 sBefore,, uint128 bBefore,,,) = IMorphoU(MORPHO).market(MARKET);
        console2.log("idleBefore", uint256(sBefore) - uint256(bBefore));
        console2.log("seedUsdc", usdcBal);

        IMorphoU.MarketParams memory mp = IMorphoU.MarketParams({
            loanToken: USDC, collateralToken: RSS, oracle: ORACLE, irm: IRM, lltv: LLTV
        });

        vm.startBroadcast(pk);
        IERC20U(USDC).approve(MORPHO, usdcBal);
        IMorphoU(MORPHO).supply(mp, usdcBal, 0, HOT, "");

        uint256 pull = IYrssU(YRSS).maxWithdraw(HOT);
        console2.log("maxWithdraw", pull);
        require(pull > 0, "NO_UNLOCK");
        IYrssU(YRSS).withdraw(pull, HOT, HOT);
        vm.stopBroadcast();

        (uint128 sAfter,, uint128 bAfter,,,) = IMorphoU(MORPHO).market(MARKET);
        console2.log("idleAfter", uint256(sAfter) - uint256(bAfter));
        console2.log("hotUsdc", IERC20U(USDC).balanceOf(HOT));
        console2.log("MISSION idle engineered into live RSS book + yRSS unlocked");
    }
}
