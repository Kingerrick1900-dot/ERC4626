// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKarReallocator} from "../src/CrownKarReallocator.sol";

interface IMetaMorphoWire {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setIsAllocator(address allocator, bool isAllocator) external;
    function isAllocator(address) external view returns (bool);
    function owner() external view returns (address);
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(MarketParams memory marketParams) external;
    function setSupplyQueue(bytes32[] calldata ids) external;
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function totalAssets() external view returns (uint256);
}

interface IPublicAllocatorWire {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    function setAdmin(address vault, address newAdmin) external;
    function setFee(address vault, uint256 newFee) external;
    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function admin(address vault) external view returns (address);
    function fee(address vault) external view returns (uint256);
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;
}

interface IMorphoWire {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IAllowlistWire {
    function setAllowed(address target, bytes4 selector, bool ok) external;
    function owner() external view returns (address);
}

interface IERC20Wire {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Wire PublicAllocator → ySYNTH · deploy CrownKarReallocator · arm multi-market caps · fire reallocate attempt · exit probe.
/// @dev Steakhouse/Gauntlet playbook. PA is intra-vault. Foreign maxIn still watched off-chain.
contract FireKarReallocator is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YSYNTH = 0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C;
    address constant CURATOR_NATIVE = 0x8Cb11A67F9734143195b24D179749534099b7558;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    address constant ALLOWLIST = 0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ORACLE_EUSD = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant ORACLE_CBBTC = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    uint256 constant LLTV_86 = 860000000000000000;

    bytes32 constant SYNTH_ID = 0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd;
    bytes32 constant CBBTC_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_ID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant IDLE_ID = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;

    uint256 constant FLOW = 50_000_000e6; // $50M PA flow
    uint256 constant CAP_SIDE = 50_000_000e6;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        IMetaMorphoWire mm = IMetaMorphoWire(YSYNTH);
        require(mm.owner() == HOT, "NOT_OWNER");

        (uint128 synSupply,, uint128 synBorrow,,,) = IMorphoWire(MORPHO).market(SYNTH_ID);
        uint256 utilBps = synSupply == 0 ? 0 : (uint256(synBorrow) * 10_000) / uint256(synSupply);
        uint256 idleBefore =
            uint256(synSupply) > uint256(synBorrow) ? uint256(synSupply) - uint256(synBorrow) : 0;

        console2.log("FIRE", "kar-reallocator");
        console2.log("ySynthAssets", mm.totalAssets());
        console2.log("synthUtilBps", utilBps);
        console2.log("synthIdleBefore", idleBefore);
        console2.log("hotUsdcBefore", IERC20Wire(USDC).balanceOf(HOT));

        vm.startBroadcast(pk);

        // 1) Grant allocators: PA + CrownCuratorNative + Landing (HOT already true)
        mm.setIsAllocator(PA, true);
        mm.setIsAllocator(CURATOR_NATIVE, true);
        mm.setIsAllocator(LANDING, true);

        // 2) Cap side markets so PA can later pull idle → SYNTH (Steakhouse multi-book)
        IMetaMorphoWire.MarketParams memory cbBtc = IMetaMorphoWire.MarketParams({
            loanToken: USDC,
            collateralToken: CBBTC,
            oracle: ORACLE_CBBTC,
            irm: IRM,
            lltv: LLTV_86
        });
        IMetaMorphoWire.MarketParams memory weth = IMetaMorphoWire.MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: ORACLE_WETH,
            irm: IRM,
            lltv: LLTV_86
        });
        IMetaMorphoWire.MarketParams memory idleM = IMetaMorphoWire.MarketParams({
            loanToken: USDC,
            collateralToken: address(0),
            oracle: address(0),
            irm: address(0),
            lltv: 0
        });

        _ensureCap(mm, cbBtc, CBBTC_ID, CAP_SIDE);
        _ensureCap(mm, weth, WETH_ID, CAP_SIDE);
        _ensureCap(mm, idleM, IDLE_ID, CAP_SIDE);

        // Queue: park books first, synth last (PA target for demand)
        bytes32[] memory queue = new bytes32[](4);
        queue[0] = IDLE_ID;
        queue[1] = CBBTC_ID;
        queue[2] = WETH_ID;
        queue[3] = SYNTH_ID;
        mm.setSupplyQueue(queue);

        // 3) PA admin + zero fee + flow caps (Kingdom-owned vault)
        if (IPublicAllocatorWire(PA).admin(YSYNTH) != HOT) {
            IPublicAllocatorWire(PA).setAdmin(YSYNTH, HOT);
        }
        IPublicAllocatorWire(PA).setFee(YSYNTH, 0);

        IPublicAllocatorWire.FlowCapsConfig[] memory caps = new IPublicAllocatorWire.FlowCapsConfig[](4);
        caps[0] = IPublicAllocatorWire.FlowCapsConfig({
            id: IDLE_ID, caps: IPublicAllocatorWire.FlowCaps({maxIn: uint128(FLOW), maxOut: uint128(FLOW)})
        });
        caps[1] = IPublicAllocatorWire.FlowCapsConfig({
            id: CBBTC_ID, caps: IPublicAllocatorWire.FlowCaps({maxIn: uint128(FLOW), maxOut: uint128(FLOW)})
        });
        caps[2] = IPublicAllocatorWire.FlowCapsConfig({
            id: WETH_ID, caps: IPublicAllocatorWire.FlowCaps({maxIn: uint128(FLOW), maxOut: uint128(FLOW)})
        });
        caps[3] = IPublicAllocatorWire.FlowCapsConfig({
            id: SYNTH_ID, caps: IPublicAllocatorWire.FlowCaps({maxIn: uint128(FLOW), maxOut: uint128(FLOW)})
        });
        IPublicAllocatorWire(PA).setFlowCaps(YSYNTH, caps);

        // 4) Deploy + arm CrownKarReallocator
        CrownKarReallocator reallocator = new CrownKarReallocator(PA, MORPHO, HOT, HOT);
        reallocator.setVault(YSYNTH, SYNTH_ID);
        reallocator.setThresholds(1_000e6, 9500);
        // risk scores: idle/bluechip ok; leave synth self as 0
        reallocator.setRiskScore(IDLE_ID, 1000);
        reallocator.setRiskScore(CBBTC_ID, 2000);
        reallocator.setRiskScore(WETH_ID, 2500);
        reallocator.setRiskScore(SYNTH_ID, 5000);
        reallocator.setArmed(true);
        // killswitch OFF (not tripped) — armed for fire; ban list empty
        reallocator.setKillswitch(false);

        mm.setIsAllocator(address(reallocator), true);

        // KAR allowlist: fireReallocate selector
        if (IAllowlistWire(ALLOWLIST).owner() == HOT) {
            IAllowlistWire(ALLOWLIST).setAllowed(
                address(reallocator), CrownKarReallocator.fireReallocate.selector, true
            );
        }

        // 5) Attempt live reallocate: find any withdrawable vault position with market idle
        uint256 pulled = _tryPullToSynth();

        vm.stopBroadcast();

        (uint128 synSupply2,, uint128 synBorrow2,,,) = IMorphoWire(MORPHO).market(SYNTH_ID);
        uint256 idleAfter =
            uint256(synSupply2) > uint256(synBorrow2) ? uint256(synSupply2) - uint256(synBorrow2) : 0;

        console2.log("CrownKarReallocator", address(reallocator));
        console2.log("paIsAllocator", mm.isAllocator(PA) ? 1 : 0);
        console2.log("curatorIsAllocator", mm.isAllocator(CURATOR_NATIVE) ? 1 : 0);
        console2.log("paAdmin", IPublicAllocatorWire(PA).admin(YSYNTH));
        (uint128 maxIn, uint128 maxOut) = IPublicAllocatorWire(PA).flowCaps(YSYNTH, SYNTH_ID);
        console2.log("paSynthMaxIn", uint256(maxIn));
        console2.log("paSynthMaxOut", uint256(maxOut));
        console2.log("pulled", pulled);
        console2.log("synthIdleAfter", idleAfter);
        console2.log("hotUsdcAfter", IERC20Wire(USDC).balanceOf(HOT));
        console2.log("exitUsdc", IERC20Wire(USDC).balanceOf(EXIT));
        console2.log("IRM", "AdaptiveCurve-armed");
        console2.log("killswitch", reallocator.killswitch() ? 1 : 0);
        console2.log("NEXT", pulled > 0 ? "exit-against-idle" : "watcher-24-7-until-idle");
    }

    function _ensureCap(
        IMetaMorphoWire mm,
        IMetaMorphoWire.MarketParams memory mp,
        bytes32 id,
        uint256 cap
    ) internal {
        (uint184 cur,,) = mm.config(id);
        if (uint256(cur) >= cap) return;
        mm.submitCap(mp, cap);
        mm.acceptCap(mp);
    }

    /// @dev Honest attempt: withdraw from side markets where ySYNTH has supply shares + market idle > 0.
    function _tryPullToSynth() internal returns (uint256 pulled) {
        bytes32[3] memory sources = [IDLE_ID, CBBTC_ID, WETH_ID];
        IPublicAllocatorWire.MarketParams memory toMp = IPublicAllocatorWire.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: ORACLE_EUSD,
            irm: IRM,
            lltv: LLTV_86
        });

        for (uint256 i; i < sources.length; ++i) {
            bytes32 id = sources[i];
            (uint256 supplyShares,,) = IMorphoWire(MORPHO).position(id, YSYNTH);
            if (supplyShares == 0) {
                console2.log("skipNoPosition");
                console2.logBytes32(id);
                continue;
            }
            (uint128 s,, uint128 b,,,) = IMorphoWire(MORPHO).market(id);
            uint256 idle = uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
            if (idle == 0) {
                console2.log("skipNoIdle");
                console2.logBytes32(id);
                continue;
            }
            (uint128 maxIn,) = IPublicAllocatorWire(PA).flowCaps(YSYNTH, SYNTH_ID);
            (, uint128 maxOut) = IPublicAllocatorWire(PA).flowCaps(YSYNTH, id);
            uint256 amt = idle;
            if (amt > maxIn) amt = maxIn;
            if (amt > maxOut) amt = maxOut;
            if (amt == 0) continue;

            (address loan, address coll, address oracle, address irm, uint256 lltv) =
                IMorphoWire(MORPHO).idToMarketParams(id);

            IPublicAllocatorWire.Withdrawal[] memory w = new IPublicAllocatorWire.Withdrawal[](1);
            w[0] = IPublicAllocatorWire.Withdrawal({
                marketParams: IPublicAllocatorWire.MarketParams({
                    loanToken: loan,
                    collateralToken: coll,
                    oracle: oracle,
                    irm: irm,
                    lltv: lltv
                }),
                amount: uint128(amt)
            });

            try IPublicAllocatorWire(PA).reallocateTo(YSYNTH, w, toMp) {
                console2.log("reallocateOk", amt);
                console2.logBytes32(id);
                pulled += amt;
            } catch (bytes memory reason) {
                console2.log("reallocateRevert", amt);
                console2.logBytes32(id);
                console2.logBytes(reason);
            }
        }
        if (pulled == 0) {
            console2.log("reallocate", "NO_WITHDRAWABLE_IDLE — PA wired; watcher hunts");
        }
    }
}
