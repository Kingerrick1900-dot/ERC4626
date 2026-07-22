// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoFixedRssLoanOracle} from "../src/MorphoFixedRssLoanOracle.sol";
import {CrownFatFlashSeed} from "../src/CrownFatFlashSeed.sol";

interface IMorphoFire {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20Fire {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IOracleFire {
    function price() external view returns (uint256);
}

/// @notice Whale fire: RSS/WETH + RSS/cbBTC Morpho markets, flash-seed from Morpho FAT inventory.
/// @dev KING_OK=1 FIRE_FAT_SEED=1 forge script script/FireFatRssWethCbbtc.s.sol:FireFatRssWethCbbtc --broadcast
contract FireFatRssWethCbbtc is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000; // nearest enabled to 75%

    address constant WETH_USDC_500 = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address constant CBTC_USDC_500 = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_FAT_SEED", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint32 twap = uint32(vm.envOr("TWAP_SEC", uint256(1800)));
        uint256 flashWeth = vm.envOr("FLASH_WETH", uint256(10 ether));
        uint256 flashCbtc = vm.envOr("FLASH_CBTC", uint256(0.5e8));

        vm.startBroadcast(pk);

        MorphoFixedRssLoanOracle oraW = new MorphoFixedRssLoanOracle(WETH_USDC_500, WETH, USDC, twap, 18);
        MorphoFixedRssLoanOracle oraC = new MorphoFixedRssLoanOracle(CBTC_USDC_500, CBTC, USDC, twap, 8);
        console2.log("Oracle RSS/WETH", address(oraW));
        console2.log("Oracle RSS/cbBTC", address(oraC));
        console2.log("pxW", oraW.price());
        console2.log("pxC", oraC.price());

        IMorphoFire.MarketParams memory mpW = IMorphoFire.MarketParams({
            loanToken: WETH,
            collateralToken: RSS,
            oracle: address(oraW),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoFire.MarketParams memory mpC = IMorphoFire.MarketParams({
            loanToken: CBTC,
            collateralToken: RSS,
            oracle: address(oraC),
            irm: IRM,
            lltv: LLTV
        });

        IMorphoFire(MORPHO).createMarket(mpW);
        IMorphoFire(MORPHO).createMarket(mpC);

        bytes32 idW = keccak256(abi.encode(mpW));
        bytes32 idC = keccak256(abi.encode(mpC));
        console2.log("MarketId RSS/WETH");
        console2.logBytes32(idW);
        console2.log("MarketId RSS/cbBTC");
        console2.logBytes32(idC);

        CrownFatFlashSeed seeder = new CrownFatFlashSeed(MORPHO, RSS, HOT, LANDING, HOT);
        console2.log("CrownFatFlashSeed", address(seeder));

        // Seeder must act onBehalf of king for Morpho supply/borrow/collateral
        IMorphoFire(MORPHO).setAuthorization(address(seeder), true);

        uint256 rssW = _rssForHf(flashWeth, oraW.price(), 1.55e18) * 101 / 100;
        uint256 rssC = _rssForHf(flashCbtc, oraC.price(), 1.55e18) * 101 / 100;
        console2.log("RSS for WETH seed (HF>=1.55)", rssW);
        console2.log("RSS for cbBTC seed (HF>=1.55)", rssC);
        require(IERC20Fire(RSS).balanceOf(HOT) >= rssW + rssC, "RSS_SHORT");

        IERC20Fire(RSS).approve(address(seeder), rssW + rssC);

        seeder.flashSeed(WETH, address(oraW), IRM, LLTV, flashWeth, rssW);
        console2.log("WETH book seeded", flashWeth);

        seeder.flashSeed(CBTC, address(oraC), IRM, LLTV, flashCbtc, rssC);
        console2.log("cbBTC book seeded", flashCbtc);

        (uint128 sW,, uint128 bW,,,) = IMorphoFire(MORPHO).market(idW);
        (uint128 sC,, uint128 bC,,,) = IMorphoFire(MORPHO).market(idC);
        console2.log("WETH supply", uint256(sW));
        console2.log("WETH borrow", uint256(bW));
        console2.log("cbBTC supply", uint256(sC));
        console2.log("cbBTC borrow", uint256(bC));

        vm.stopBroadcast();
    }

    /// @dev rss such that (rss * px / 1e36) / flashAmt >= hfWad/1e18
    function _rssForHf(uint256 flashAmt, uint256 px, uint256 hfWad) internal pure returns (uint256) {
        return flashAmt * hfWad * 1e36 / (px * 1e18);
    }
}
