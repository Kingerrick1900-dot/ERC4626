// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownChainlinkXauOracle} from "../src/CrownChainlinkXauOracle.sol";
import {CrownGold} from "../src/CrownGold.sol";

interface IMorphoG {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory) external;
    function idToMarketParams(bytes32)
        external
        view
        returns (address, address, address, address, uint256);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function isLltvEnabled(uint256) external view returns (bool);
}

interface IMetaMorphoG {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function submitCap(MarketParams memory, uint256) external;
    function pendingCap(bytes32) external view returns (uint184, uint64);
}

interface IERC20G {
    function balanceOf(address) external view returns (uint256);
}

/// @notice KING_GO=1 FIRE_GOLD_SOVEREIGN=1 — complete gold lane with NO king Morpho loan.
/// @dev Markets + oracle + free kXAU treasury + yELE caps. Does not borrow or post collateral.
contract FireGoldSovereign is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant GOLD = 0x76822B470DeC1b94Df4219727288e7a196224853;
    address constant ORACLE_10 = 0xCf2BC42FC9d158CCd77462c24670F17Cc57dBEd0;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant XAU_FEED = 0x5213eBB69743b85644dbB6E25cdF994aFBb8cF31;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;
    uint256 constant CAP = 14_000_000e6;
    uint256 constant DEFAULT_MINT = 100_000e8; // free treasury kXAU

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_GOLD_SOVEREIGN", uint256(0)) == 1, "NEED FIRE_GOLD_SOVEREIGN=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IMorphoG(MORPHO).isLltvEnabled(LLTV_77), "LLTV77");
        require(IMorphoG(MORPHO).isLltvEnabled(LLTV_915), "LLTV915");

        uint256 mintAmt = vm.envOr("GOLD_MINT", DEFAULT_MINT);

        IMorphoG.MarketParams memory mp91 =
            IMorphoG.MarketParams(USDC, GOLD, ORACLE_10, IRM, LLTV_915);
        IMorphoG.MarketParams memory mp77 =
            IMorphoG.MarketParams(USDC, GOLD, ORACLE_10, IRM, LLTV_77);
        bytes32 id91 = keccak256(abi.encode(mp91));
        bytes32 id77 = keccak256(abi.encode(mp77));

        (uint256 s91, uint128 b91, uint128 c91) = IMorphoG(MORPHO).position(id91, HOT);
        require(s91 == 0 && b91 == 0 && c91 == 0, "KING_MUST_HAVE_NO_GOLD91_LOAN");
        (uint256 s77, uint128 b77, uint128 c77) = IMorphoG(MORPHO).position(id77, HOT);
        require(s77 == 0 && b77 == 0 && c77 == 0, "KING_MUST_HAVE_NO_GOLD77_LOAN");

        console2.log("policy", "NO_KING_LOAN_SOVEREIGN_GOLD");
        console2.log("hotGoldBefore", IERC20G(GOLD).balanceOf(HOT));

        vm.startBroadcast(pk);

        (address loan77,,,,) = IMorphoG(MORPHO).idToMarketParams(id77);
        if (loan77 == address(0)) {
            IMorphoG(MORPHO).createMarket(mp77);
            console2.log("createdGold77");
        }

        CrownChainlinkXauOracle xauOra = new CrownChainlinkXauOracle(XAU_FEED, 1 days);
        console2.log("xauRefOracle", address(xauOra));
        console2.log("xauRefPrice", xauOra.price());

        if (mintAmt > 0) {
            CrownGold(GOLD).mint(HOT, mintAmt);
            console2.log("mintedFreeGold", mintAmt);
        }

        IMetaMorphoG(YELE).submitCap(
            IMetaMorphoG.MarketParams(USDC, GOLD, ORACLE_10, IRM, LLTV_915), CAP
        );
        IMetaMorphoG(YELE).submitCap(
            IMetaMorphoG.MarketParams(USDC, GOLD, ORACLE_10, IRM, LLTV_77), CAP
        );

        vm.stopBroadcast();

        (, uint64 v91) = IMetaMorphoG(YELE).pendingCap(id91);
        (, uint64 v77) = IMetaMorphoG(YELE).pendingCap(id77);
        console2.logBytes32(id91);
        console2.logBytes32(id77);
        console2.log("pendingCap91ValidAt", uint256(v91));
        console2.log("pendingCap77ValidAt", uint256(v77));
        console2.log("hotGoldAfter", IERC20G(GOLD).balanceOf(HOT));
        console2.log("GOLD_SOVEREIGN_OK", uint256(1));
    }
}
