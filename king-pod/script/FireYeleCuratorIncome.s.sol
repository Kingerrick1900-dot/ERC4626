// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoY {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setFee(uint256 newFee) external;
    function setFeeRecipient(address newFeeRecipient) external;
    function setIsAllocator(address allocator, bool isAllocator) external;
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function setSupplyQueue(bytes32[] calldata ids) external;
    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function isAllocator(address) external view returns (bool);
}

interface IPublicAllocatorY {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

/// @notice KING_GO=1 FIRE_YELE_INCOME=1 — curator income arm: fee, recipient, TEN cap, queue, PA.
/// @dev Fee is MetaMorpho performance fee on interest (WAD). Does not mint USDC; arms vault to earn when TVL lives.
contract FireYeleCuratorIncome is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant ORACLE_77 = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;
    // 10% performance fee on interest (MetaMorpho max typically 50%)
    uint256 constant FEE_WAD = 0.1e18;
    uint256 constant TEN_CAP = 14_000_000e6; // $14M
    uint128 constant FLOW = 700_000e6; // $700k PA lane

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_YELE_INCOME", uint256(0)) == 1, "NEED FIRE_YELE_INCOME=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address feeTo = vm.envOr("FEE_TO", HOT);
        uint256 feeWad = vm.envOr("FEE_WAD", FEE_WAD);

        IMetaMorphoY.MarketParams memory tenMp =
            IMetaMorphoY.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);
        IMetaMorphoY.MarketParams memory eleMp =
            IMetaMorphoY.MarketParams(USDC, ELE, ORACLE_77, IRM, LLTV_77);

        console2.log("feeBefore", uint256(IMetaMorphoY(YELE).fee()));
        console2.log("feeRecipientBefore", IMetaMorphoY(YELE).feeRecipient());

        vm.startBroadcast(pk);

        IMetaMorphoY(YELE).setFeeRecipient(feeTo);
        IMetaMorphoY(YELE).setFee(feeWad);

        if (!IMetaMorphoY(YELE).isAllocator(PA)) {
            IMetaMorphoY(YELE).setIsAllocator(PA, true);
        }
        if (!IMetaMorphoY(YELE).isAllocator(HOT)) {
            IMetaMorphoY(YELE).setIsAllocator(HOT, true);
        }

        // Submit TEN $10 market cap (timelock before acceptCap)
        (, bool tenOn,) = IMetaMorphoY(YELE).config(TEN);
        if (!tenOn) {
            IMetaMorphoY(YELE).submitCap(tenMp, TEN_CAP);
            console2.log("submittedTenCap", TEN_CAP);
        }

        // Supply queue: only enabled markets (TEN joins after acceptCap post-timelock)
        if (tenOn) {
            bytes32[] memory q2 = new bytes32[](2);
            q2[0] = ELE77;
            q2[1] = TEN;
            IMetaMorphoY(YELE).setSupplyQueue(q2);
        } else {
            bytes32[] memory q1 = new bytes32[](1);
            q1[0] = ELE77;
            IMetaMorphoY(YELE).setSupplyQueue(q1);
        }

        // PA flow caps on enabled markets only (TEN after acceptCap)
        if (tenOn) {
            IPublicAllocatorY.FlowCapsConfig[] memory caps2 = new IPublicAllocatorY.FlowCapsConfig[](2);
            caps2[0] = IPublicAllocatorY.FlowCapsConfig({
                id: ELE77, caps: IPublicAllocatorY.FlowCaps({maxIn: FLOW, maxOut: FLOW})
            });
            caps2[1] = IPublicAllocatorY.FlowCapsConfig({
                id: TEN, caps: IPublicAllocatorY.FlowCaps({maxIn: FLOW, maxOut: FLOW})
            });
            IPublicAllocatorY(PA).setFlowCaps(YELE, caps2);
        } else {
            IPublicAllocatorY.FlowCapsConfig[] memory caps1 = new IPublicAllocatorY.FlowCapsConfig[](1);
            caps1[0] = IPublicAllocatorY.FlowCapsConfig({
                id: ELE77, caps: IPublicAllocatorY.FlowCaps({maxIn: FLOW, maxOut: FLOW})
            });
            IPublicAllocatorY(PA).setFlowCaps(YELE, caps1);
        }

        vm.stopBroadcast();

        console2.log("feeAfter", uint256(IMetaMorphoY(YELE).fee()));
        console2.log("feeRecipientAfter", IMetaMorphoY(YELE).feeRecipient());
        console2.log("feeTo", feeTo);
        console2.log("land", LAND);
        (uint128 tenIn,) = IPublicAllocatorY(PA).flowCaps(YELE, TEN);
        console2.log("paTenMaxIn", uint256(tenIn));
        console2.log("YELE_CURATOR_INCOME_OK", uint256(1));
    }
}
