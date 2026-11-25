// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPassportBorrow, IMorphoPassport} from "../src/CrownPassportBorrow.sol";

/// @notice Deploy Move 4 passport. Env: PRIVATE_KEY
contract DeployPassportBorrow is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ORACLE_CBBTC = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    uint256 constant LLTV_86 = 860000000000000000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        IMorphoPassport.MarketParams memory cb = IMorphoPassport.MarketParams({
            loanToken: USDC, collateralToken: CBBTC, oracle: ORACLE_CBBTC, irm: IRM, lltv: LLTV_86
        });
        IMorphoPassport.MarketParams memory wh = IMorphoPassport.MarketParams({
            loanToken: USDC, collateralToken: WETH, oracle: ORACLE_WETH, irm: IRM, lltv: LLTV_86
        });

        vm.startBroadcast(pk);
        CrownPassportBorrow p = new CrownPassportBorrow(
            MORPHO, USDC, CBBTC, WETH, HOT, KING_VAULT, HOT, cb, wh
        );
        p.setArmed(true);
        vm.stopBroadcast();

        console2.log("CrownPassportBorrow", address(p));
        console2.log("NEXT: Morpho.setAuthorization(passport, true) from HOT");
        console2.log("NEXT: seed cbBTC or WETH on HOT, then FireMove4Passport");
    }
}
