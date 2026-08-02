// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanEngineFeed} from "../src/CrownElepanEngineFeed.sol";

interface IMorphoF {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IZkF {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256 value, uint256 ts, uint256 flag);
    function minThreshold() external view returns (uint256);
}

/// @notice KING_GO=1 FIRE_ENGINE_FEED=1 — post ELE, draw idle USDC → Landing, reopen loan engine.
/// @dev ENGINE_ASK defaults $50M. Set 0 to draw-only. Use --slow on EIP-7702 hot.
contract FireElepanEngineFeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    bytes32 constant MID = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant MAX_LTV_BPS = 6450;
    uint256 constant DEFAULT_ASK = 50_000_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ENGINE_FEED", uint256(0)) == 1, "NEED FIRE_ENGINE_FEED=1");
        require(IZkF(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 attest,,) = IZkF(GATE).attestations(HOT);
        require(attest >= IZkF(GATE).minThreshold(), "BELOW_THRESHOLD");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 ele = IERC20F(ELE).balanceOf(HOT);
        uint256 ask = vm.envOr("ENGINE_ASK", DEFAULT_ASK);
        (, , uint128 collNow) = IMorphoF(MORPHO).position(MID, HOT);
        uint256 totalColl = uint256(collNow) + ele;
        if (ask > 0) {
            uint256 maxB = (totalColl * MAX_LTV_BPS * 1e6) / (10_000 * 1e8);
            require(maxB >= ask, "COLL");
            require(IERC20F(USDC).balanceOf(MORPHO) >= ask, "FLASH");
            // Soft HF collUSD/debt >= 1.55
            uint256 hf = (totalColl * 1e18 * 1e6) / (ask * 1e8);
            require(hf >= 1.55e18, "HF");
            console2.log("hfWad", hf);
        }

        uint256 landBefore = IERC20F(USDC).balanceOf(LAND);
        console2.log("zkAttestUsdc6", attest);
        console2.log("eleFree", ele);
        console2.log("engineAsk", ask);
        console2.log("landBefore", landBefore);

        vm.startBroadcast(pk);
        CrownElepanEngineFeed feed = new CrownElepanEngineFeed(HOT, LAND);
        console2.log("feed", address(feed));
        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(feed))) {
            IMorphoF(MORPHO).setAuthorization(address(feed), true);
        }
        IERC20F(ELE).approve(address(feed), type(uint256).max);
        IERC20F(USDC).approve(address(feed), type(uint256).max);
        feed.feed(ele, ask);
        vm.stopBroadcast();

        (, uint128 bShares, uint128 collAfter) = IMorphoF(MORPHO).position(MID, HOT);
        (uint128 sa,, uint128 ba,,,) = IMorphoF(MORPHO).market(MID);
        uint256 landAfter = IERC20F(USDC).balanceOf(LAND);
        console2.log("posColl", uint256(collAfter));
        console2.log("posBorrowShares", uint256(bShares));
        console2.log("marketSupply", uint256(sa));
        console2.log("marketBorrow", uint256(ba));
        console2.log("landAfter", landAfter);
        console2.log("landDelta", landAfter > landBefore ? landAfter - landBefore : 0);
        console2.log("ENGINE_FEED_OK", uint256(1));
    }
}
