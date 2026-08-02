// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFixedOracle} from "../src/CrownFixedOracle.sol";

interface IERC20E {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoE {
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
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
    function isLltvEnabled(uint256) external view returns (bool);
}

interface IPae {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128, uint128);
}

interface IYeleE {
    function setSupplyQueue(bytes32[] calldata) external;
    function config(bytes32) external view returns (uint184, bool, uint64);
}

/// @notice Engineer exit — REAL Morpho APIs (DeepSeek draft corrected).
/// @dev KING_GO=1 FIRE_ENGINEER_EXIT=1
///      1) PA flow caps on kingdom vault (not MetaMorpho.setMaxIn — that does not exist)
///      2) Deploy Morpho-scale fixed oracle ($1 → 1e34, $1.50 → 1.5e34)
///      3) createMarket ELE/USDC @ 91.5% LLTV
///      4) Supply FREE ELE (wallet) as coll — does not yank 86M coll while $50M debt lives on 77% market
///      5) Borrow only liquid idle on the NEW market → Landing
///      Empty new book ⇒ borrow returns 0 (no known-revert 700k broadcast).
contract FireEngineerExit is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532; // kingdom timelock-0 vault
    bytes32 constant ELE_USDC_77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant LLTV_915 = 915000000000000000;
    /// @dev Morpho scale: $1.50 ELE → 1.5e34 (not 1.5e18).
    uint256 constant ORACLE_150 = 15e33;
    uint128 constant FLOW = 700_000e6;
    uint256 constant ASK = 700_000e6;
    uint256 constant MIN_ETH = 2e14;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ENGINEER_EXIT", uint256(0)) == 1, "NEED FIRE_ENGINEER_EXIT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(HOT.balance >= MIN_ETH, "GAS_FLOOR");
        require(IMorphoE(MORPHO).isLltvEnabled(LLTV_915), "LLTV");

        uint256 oraclePrice = vm.envOr("ORACLE_PRICE", ORACLE_150);
        address vault = vm.envOr("VAULT", YELE_K);

        vm.startBroadcast(pk);

        // 1) Flow caps — Public Allocator (king owns vault)
        IPae.FlowCapsConfig[] memory caps = new IPae.FlowCapsConfig[](2);
        caps[0] = IPae.FlowCapsConfig({
            id: WETH_USDC, caps: IPae.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        caps[1] = IPae.FlowCapsConfig({
            id: ELE_USDC_77, caps: IPae.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        IPae(PA).setFlowCaps(vault, caps);

        // Supply queue WETH → ELE on kingdom vault if both enabled
        (, bool wethOn,) = IYeleE(vault).config(WETH_USDC);
        (, bool eleOn,) = IYeleE(vault).config(ELE_USDC_77);
        if (wethOn && eleOn) {
            bytes32[] memory q = new bytes32[](2);
            q[0] = WETH_USDC;
            q[1] = ELE_USDC_77;
            IYeleE(vault).setSupplyQueue(q);
        }

        // 2) Oracle — Morpho scale
        CrownFixedOracle oracle = new CrownFixedOracle(oraclePrice);
        console2.log("oracle", address(oracle));
        console2.log("oraclePrice", oracle.price());

        // 3) Create 91.5% market (idempotent if already exists)
        IMorphoE.MarketParams memory mp = IMorphoE.MarketParams({
            loanToken: USDC,
            collateralToken: ELE,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV_915
        });
        bytes32 id = keccak256(abi.encode(mp));
        (address loan,,,,) = IMorphoE(MORPHO).idToMarketParams(id);
        if (loan == address(0)) {
            IMorphoE(MORPHO).createMarket(mp);
            console2.log("createdMarket");
        } else {
            console2.log("marketExists");
        }
        console2.logBytes32(id);

        // 4) Supply FREE wallet ELE only (engine debt stays on 77% book)
        uint256 freeEle = IERC20E(ELE).balanceOf(HOT);
        console2.log("freeEle", freeEle);
        if (freeEle > 0) {
            IERC20E(ELE).approve(MORPHO, freeEle);
            IMorphoE(MORPHO).supplyCollateral(mp, freeEle, HOT, "");
        }

        // 5) Borrow liquid idle only → Landing (never fake 700k)
        IMorphoE(MORPHO).accrueInterest(mp);
        (uint128 sa,, uint128 ba,,,) = IMorphoE(MORPHO).market(id);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        console2.log("newMarketIdle", idle);
        uint256 borrowed;
        if (idle > 1) {
            uint256 want = ASK;
            if (want > idle - 1) want = idle - 1;
            (borrowed,) = IMorphoE(MORPHO).borrow(mp, want, 0, HOT, LAND);
        }
        console2.log("borrowedToLanding", borrowed);
        console2.log("landUsdc", IERC20E(USDC).balanceOf(LAND));
        console2.log("ENGINEER_EXIT_OK", uint256(1));

        vm.stopBroadcast();
    }
}
