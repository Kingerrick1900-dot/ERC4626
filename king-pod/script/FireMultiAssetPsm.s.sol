// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../src/lib/Core.sol";
import {CrownMultiAssetPsm} from "../src/stack/CrownMultiAssetPsm.sol";

/// @notice Deploy Base multi-asset PSM (USDC/USDT/DAI/WETH/EURC) with Chainlink feeds.
/// @dev Does NOT touch live ERC-7540 / ERC-7683 contracts. Optional vault wrap uses same
///      CrownElepanAsyncVault bytecode pointing at this PSM for USDC queue only.
///
/// KING_GO=1 forge script script/FireMultiAssetPsm.s.sol:FireMultiAssetPsm \
///   --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireMultiAssetPsm is Script {
    address constant BASE_HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant BASE_EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;

    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;

    // Chainlink Base feeds
    address constant FEED_USDC_USD = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address constant FEED_USDT_USD = 0xf19d560eB8d2ADf07BD6D13ed03e1D11215721F9;
    address constant FEED_DAI_USD = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address constant FEED_ETH_USD = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    // Capped EURC/USD — use latestAnswer (latestRoundData reverts)
    address constant FEED_EURC_USD = 0x8438ee84b847FA4e462d906bbdf4B11341434d13;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == BASE_HOT, "BASE_HOT");

        vm.startBroadcast(pk);

        CrownMultiAssetPsm psm = new CrownMultiAssetPsm(BASE_EUSD, USDC, LANDING, WETH, BASE_HOT);
        console2.log("MULTI_ASSET_PSM", address(psm));

        // List USDC first (canonical redeemUsdc path), then extras.
        psm.listAsset(USDC, FEED_USDC_USD, 6, false);
        psm.listAsset(USDT, FEED_USDT_USD, 6, false);
        psm.listAsset(DAI, FEED_DAI_USD, 18, false);
        psm.listAsset(WETH, FEED_ETH_USD, 18, false);
        psm.listAsset(EURC, FEED_EURC_USD, 6, true);

        console2.log("assetCount", psm.assetCount());
        console2.log("usdc", psm.usdc());
        console2.log("quoteUsdc1", psm.quoteAsset(USDC, 1e18));
        console2.log("quoteUsdt1", psm.quoteAsset(USDT, 1e18));
        console2.log("quoteDai1", psm.quoteAsset(DAI, 1e18));
        console2.log("quoteWeth1", psm.quoteAsset(WETH, 1e18));
        console2.log("quoteEurc1", psm.quoteAsset(EURC, 1e18));

        // Optional dust seed from hot wallet if balances exist.
        _seedDust(psm, USDC, 1e6); // $1
        _seedDust(psm, USDT, 1e6);
        _seedDust(psm, DAI, 1e18);
        _seedDust(psm, EURC, 1e6);
        // WETH: 0.0001 ETH worth if available
        _seedDust(psm, WETH, 1e14);

        vm.stopBroadcast();
        console2.log("MULTI_ASSET_PSM_OK", uint256(1));
    }

    function _seedDust(CrownMultiAssetPsm psm, address token, uint256 want) internal {
        uint256 bal = IERC20(token).balanceOf(BASE_HOT);
        if (bal == 0) {
            console2.log("skipSeed", token);
            return;
        }
        uint256 amt = want > bal ? bal : want;
        IERC20(token).approve(address(psm), amt);
        psm.seed(token, amt);
        console2.log("seeded", token);
        console2.log("seedAmt", amt);
    }
}
