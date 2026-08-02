// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLeverageExtractor} from "../src/CrownLeverageExtractor.sol";

interface IYeleF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function acceptCap(MarketParams calldata) external;
    function pendingCap(bytes32) external view returns (uint184 value, uint64 validAt);
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function setSupplyQueue(bytes32[] calldata) external;
    function setIsAllocator(address, bool) external;
    function isAllocator(address) external view returns (bool);
    function deposit(uint256, address) external returns (uint256);
    function asset() external view returns (address);
}

interface IMorphoF {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IZkF {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, uint256);
    function minThreshold() external view returns (uint256);
}

/// @notice Full king-source disk fill when WETH cap live + hot holds USDC.
/// @dev KING_GO=1 FIRE_DISK_FILL=1 ASK_USDC=700000000000
///      Steps: acceptCap if ready → supplyQueue WETH→ELE → deposit USDC → curatorDiskFill → Landing
contract FireDiskFill700k is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant LLTV_86 = 860000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_DISK_FILL", uint256(0)) == 1, "NEED FIRE_DISK_FILL=1");
        require(IZkF(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 attest,,) = IZkF(GATE).attestations(HOT);
        require(attest >= IZkF(GATE).minThreshold(), "BELOW_THRESHOLD");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IYeleF(YELE).asset() == USDC, "YELE_ASSET");

        uint256 ask = vm.envOr("ASK_USDC", uint256(700_000e6));
        (uint184 pend, uint64 validAt) = IYeleF(YELE).pendingCap(WETH_USDC);
        (, bool wethOn,) = IYeleF(YELE).config(WETH_USDC);
        console2.log("pendingCap", uint256(pend));
        console2.log("capValidAt", uint256(validAt));
        console2.log("wethEnabled", wethOn ? uint256(1) : uint256(0));
        console2.log("hotUsdc", IERC20F(USDC).balanceOf(HOT));
        console2.log("ask", ask);

        bool capReady = !wethOn && pend > 0 && block.timestamp >= uint256(validAt);
        require(wethOn || capReady, "WETH_CAP_LOCKED");
        require(IERC20F(USDC).balanceOf(HOT) >= ask, "NEED_USDC_ON_HOT");

        uint256 landBefore = IERC20F(USDC).balanceOf(LAND);

        vm.startBroadcast(pk);
        if (capReady) {
            IYeleF(YELE).acceptCap(
                IYeleF.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86)
            );
            console2.log("ACCEPTED_WETH_CAP", uint256(1));
        }

        bytes32[] memory q = new bytes32[](2);
        q[0] = WETH_USDC;
        q[1] = ELE_USDC;
        IYeleF(YELE).setSupplyQueue(q);

        IERC20F(USDC).approve(YELE, ask);
        IYeleF(YELE).deposit(ask, HOT);
        console2.log("DEPOSITED_YELE", ask);

        address existing = vm.envOr("EXTRACTOR", address(0));
        CrownLeverageExtractor x = existing == address(0)
            ? new CrownLeverageExtractor(HOT, LAND)
            : CrownLeverageExtractor(payable(existing));
        console2.log("extractor", address(x));

        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(x))) {
            IMorphoF(MORPHO).setAuthorization(address(x), true);
        }
        if (!IYeleF(YELE).isAllocator(address(x))) {
            IYeleF(YELE).setIsAllocator(address(x), true);
        }

        x.curatorDiskFill(ask);
        vm.stopBroadcast();

        uint256 landAfter = IERC20F(USDC).balanceOf(LAND);
        uint256 delta = landAfter > landBefore ? landAfter - landBefore : 0;
        console2.log("landDelta", delta);
        require(delta + 1e6 >= ask, "LANDING_MISS");
        console2.log("DISK_FILL_700K_OK", uint256(1));
    }
}
