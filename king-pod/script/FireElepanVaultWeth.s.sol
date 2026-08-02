// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

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

interface IMetaMorpho {
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
    function acceptTimelock() external;
    function timelock() external view returns (uint256);
    function curator() external view returns (address);
    function fee() external view returns (uint256);
    function asset() external view returns (address);
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function owner() external view returns (address);
}

interface IPublicAllocator {
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
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

/// @notice Deploy yELEPAN-WETH MetaMorpho (WETH primary workaround) + PA flow caps + 2d timelock.
/// @dev KING_GO=1 FIRE_VAULT=1. Bootstrap timelock=0 so caps apply now; then submitTimelock(2 days).
contract FireElepanVaultWeth is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ORACLE_WETH = 0xF927B35E62A0111Da1A5D4Da63FA57E473B525E5;
    address constant MM_FACTORY = 0xFf62A7c278C62eD665133147129245053Bbf5918;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    uint256 constant LLTV = 770000000000000000; // 77%
    bytes32 constant MARKET_WETH = 0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44;

    // ~50M Elepan coll @ $1 × 77% LLTV ≈ $38.5M debt capacity → ~20k WETH @ ~$2k
    uint256 constant DEFAULT_CAP_WETH = 20_000 ether;
    uint256 constant PERF_FEE = 0.1e18; // 10%
    uint256 constant TIMELOCK_2D = 2 days;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_VAULT", uint256(0)) == 1, "NEED FIRE_VAULT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 capWeth = vm.envOr("CAP_WETH", DEFAULT_CAP_WETH);
        address vaultExisting = vm.envOr("VAULT", address(0));

        IMetaMorpho.MarketParams memory mp = IMetaMorpho.MarketParams({
            loanToken: WETH,
            collateralToken: ELEPAN,
            oracle: ORACLE_WETH,
            irm: IRM,
            lltv: LLTV
        });
        require(keccak256(abi.encode(mp)) == MARKET_WETH, "MARKET_ID");

        vm.startBroadcast(pk);

        address vault = vaultExisting;
        if (vault == address(0)) {
            bytes32 salt = keccak256(abi.encodePacked("King-Elepan-WETH-yVault-v1", HOT));
            vault = IMetaMorphoFactory(MM_FACTORY).createMetaMorpho(
                HOT, 0, WETH, "King Elepan WETH Vault", "yELEPAN-WETH", salt
            );
            IMetaMorpho mm = IMetaMorpho(vault);
            mm.setCurator(HOT);
            mm.setIsAllocator(HOT, true);
            mm.setFeeRecipient(HOT);
            mm.setFee(PERF_FEE);
            mm.submitCap(mp, capWeth);
            mm.acceptCap(mp);
            bytes32[] memory q = new bytes32[](1);
            q[0] = MARKET_WETH;
            mm.setSupplyQueue(q);

            // Public Allocator
            mm.setIsAllocator(PA, true);
            IPublicAllocator(PA).setAdmin(vault, HOT);
            IPublicAllocator(PA).setFee(vault, 0);
            IPublicAllocator.FlowCapsConfig[] memory caps = new IPublicAllocator.FlowCapsConfig[](1);
            caps[0] = IPublicAllocator.FlowCapsConfig({
                id: MARKET_WETH,
                caps: IPublicAllocator.FlowCaps({maxIn: uint128(capWeth), maxOut: uint128(capWeth)})
            });
            IPublicAllocator(PA).setFlowCaps(vault, caps);

            // Standard 2-day timelock after bootstrap (current timelock=0 → accept now)
            mm.submitTimelock(TIMELOCK_2D);
            mm.acceptTimelock();
        }

        vm.stopBroadcast();

        IMetaMorpho mmv = IMetaMorpho(vault);
        console2.log("Vault yELEPAN-WETH", vault);
        console2.log("asset", mmv.asset());
        console2.log("owner", mmv.owner());
        console2.log("curator", mmv.curator());
        console2.log("fee", mmv.fee());
        console2.log("timelock", mmv.timelock());
        (uint184 cap,,) = mmv.config(MARKET_WETH);
        console2.log("supplyCapWETH", uint256(cap));
        (uint128 maxIn, uint128 maxOut) = IPublicAllocator(PA).flowCaps(vault, MARKET_WETH);
        console2.log("paMaxIn", uint256(maxIn));
        console2.log("paMaxOut", uint256(maxOut));
    }
}
