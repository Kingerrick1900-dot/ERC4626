// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoFixedElepanUsdcOracle} from "../src/MorphoFixedElepanUsdcOracle.sol";

interface IMorphoM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IMetaMorphoFactory {
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (address);
}

interface IMetaMorphoM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setCurator(address) external;
    function setIsAllocator(address, bool) external;
    function setFee(uint256) external;
    function setFeeRecipient(address) external;
    function submitCap(MarketParams memory, uint256) external;
    function acceptCap(MarketParams memory) external;
    function setSupplyQueue(bytes32[] calldata) external;
    function submitTimelock(uint256) external;
    function curator() external view returns (address);
    function fee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function asset() external view returns (address);
    function config(bytes32) external view returns (uint184, bool, uint64);
}

interface IPublicAllocatorM {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setAdmin(address vault, address newAdmin) external;
    function setFee(address vault, uint256 newFee) external;
    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
}

/// @notice Elepan moat + yELEPAN-USDC (mirror of RSS moat + yRSS).
/// @dev KING_GO=1 FIRE_MOAT=1. Soft $1 Elepan/USDC market + MetaMorpho USDC vault.
contract FireElepanMoatYvault is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant MM_FACTORY = 0xFf62A7c278C62eD665133147129245053Bbf5918;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    uint256 constant LLTV = 770000000000000000; // 77%
    uint256 constant PERF = 0.1e18; // 10%
    uint256 constant CAP_USDC = 14_000_000e6; // $14M like yRSS
    uint256 constant FLOW = 700_000e6; // $700k PA like moat

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MOAT", uint256(0)) == 1, "NEED FIRE_MOAT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address oraExisting = vm.envOr("ORACLE_USDC", address(0));
        address vaultExisting = vm.envOr("VAULT", address(0));

        vm.startBroadcast(pk);

        MorphoFixedElepanUsdcOracle ora;
        if (oraExisting == address(0)) {
            ora = new MorphoFixedElepanUsdcOracle();
        } else {
            ora = MorphoFixedElepanUsdcOracle(oraExisting);
        }
        console2.log("Oracle Elepan/USDC", address(ora));
        console2.log("px", ora.price());
        require(ora.price() == 1e34, "PX");

        IMorphoM.MarketParams memory mp = IMorphoM.MarketParams({
            loanToken: USDC,
            collateralToken: ELEPAN,
            oracle: address(ora),
            irm: IRM,
            lltv: LLTV
        });
        bytes32 id = keccak256(abi.encode(mp));

        (address loan,,,,) = IMorphoM(MORPHO).idToMarketParams(id);
        if (loan == address(0)) {
            IMorphoM(MORPHO).createMarket(mp);
            console2.log("created Elepan/USDC market");
        } else {
            console2.log("exists Elepan/USDC market");
        }
        console2.logBytes32(id);

        address vault = vaultExisting;
        if (vault == address(0)) {
            bytes32 salt = keccak256(abi.encodePacked("King-Elepan-USDC-yVault-v1", HOT));
            vault = IMetaMorphoFactory(MM_FACTORY).createMetaMorpho(
                HOT, 0, USDC, "King Elepan USDC Vault", "yELEPAN-USDC", salt
            );
            IMetaMorphoM mm = IMetaMorphoM(vault);
            mm.setCurator(HOT);
            mm.setIsAllocator(HOT, true);
            mm.setFeeRecipient(LANDING); // fee shares → Landing (like yRSS→Landing path)
            mm.setFee(PERF);

            IMetaMorphoM.MarketParams memory mmp = IMetaMorphoM.MarketParams({
                loanToken: USDC,
                collateralToken: ELEPAN,
                oracle: address(ora),
                irm: IRM,
                lltv: LLTV
            });
            mm.submitCap(mmp, CAP_USDC);
            mm.acceptCap(mmp);

            bytes32[] memory q = new bytes32[](1);
            q[0] = id;
            mm.setSupplyQueue(q);

            mm.setIsAllocator(PA, true);
            IPublicAllocatorM(PA).setAdmin(vault, HOT);
            IPublicAllocatorM(PA).setFee(vault, 0);
            IPublicAllocatorM.FlowCapsConfig[] memory caps = new IPublicAllocatorM.FlowCapsConfig[](1);
            caps[0] = IPublicAllocatorM.FlowCapsConfig({
                id: id, caps: IPublicAllocatorM.FlowCaps({maxIn: uint128(FLOW), maxOut: uint128(FLOW)})
            });
            IPublicAllocatorM(PA).setFlowCaps(vault, caps);

            // Harden timelock after bootstrap (increase applies immediately on MM)
            mm.submitTimelock(2 days);
        }

        vm.stopBroadcast();

        IMetaMorphoM mmv = IMetaMorphoM(vault);
        console2.log("yELEPAN-USDC", vault);
        console2.log("asset", mmv.asset());
        console2.log("curator", mmv.curator());
        console2.log("fee", mmv.fee());
        console2.log("feeRecipient", mmv.feeRecipient());
        (uint184 cap,,) = mmv.config(id);
        console2.log("supplyCapUSDC", uint256(cap));
        console2.log("MOAT_YVAULT_LIVE", uint256(1));
    }
}
