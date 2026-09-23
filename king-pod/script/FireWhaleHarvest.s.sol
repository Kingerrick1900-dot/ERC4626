// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownWhaleHarvest} from "../src/CrownWhaleHarvest.sol";

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @dev KING_GO=1 forge script script/FireWhaleHarvest.s.sol:FireWhaleHarvest --rpc-url $BASE_RPC_URL --broadcast --slow
///      Optional: VACUUM=1 to call vacuumAll after deploy. HARVEST_ID=0x… HARVEST_MAX=… for single book.
contract FireWhaleHarvest is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;

    // Deep foreign books
    bytes32 constant MKT_CBBTC_USDC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant MKT_WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant MKT_USDE_USDC = 0x54cf9be57fdfa6457a660991907434ff9d295c465a603a50126ff647d50b7354;
    bytes32 constant MKT_CBBTC_EURC = 0x67ebd84b2fb39e3bc5a13d97e4c07abe1ea617e40654826e9abce252e95f049e;
    // Kingdom Boss eUSD/USDC
    bytes32 constant MKT_BOSS = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address existing = vm.envOr("HARVEST", address(0));

        vm.startBroadcast(pk);

        CrownWhaleHarvest h;
        if (existing == address(0)) {
            h = new CrownWhaleHarvest(MORPHO, HOT, LANDING, HOT);
            h.addMarket(MKT_BOSS);
            h.addMarket(MKT_CBBTC_USDC);
            h.addMarket(MKT_WETH_USDC);
            h.addMarket(MKT_USDE_USDC);
            h.addMarket(MKT_CBBTC_EURC);
            // approve collaterals king may use
            _approveMax(EUSD, address(h));
            _approveMax(CBBTC, address(h));
            _approveMax(WETH, address(h));
            console2.log("CrownWhaleHarvest", address(h));
        } else {
            h = CrownWhaleHarvest(existing);
            console2.log("USING", existing);
        }

        if (vm.envOr("VACUUM", uint256(0)) == 1) {
            uint256 got = h.vacuumAll();
            console2.log("vacuumAll", got);
        }

        bytes32 one = vm.envOr("HARVEST_ID", bytes32(0));
        if (one != bytes32(0)) {
            uint256 maxLoan = vm.envOr("HARVEST_MAX", uint256(0));
            uint256 borrowed = h.harvest(one, 0, maxLoan);
            console2.log("harvest", borrowed);
        }

        vm.stopBroadcast();

        _logIdle(h, MKT_BOSS, "BOSS");
        _logIdle(h, MKT_CBBTC_USDC, "CBBTC_USDC");
        _logIdle(h, MKT_WETH_USDC, "WETH_USDC");
        _logIdle(h, MKT_USDE_USDC, "USDE_USDC");
        _logIdle(h, MKT_CBBTC_EURC, "CBBTC_EURC");
    }

    function _approveMax(address token, address spender) internal {
        if (IERC20A(token).allowance(HOT, spender) < type(uint256).max / 2) {
            IERC20A(token).approve(spender, type(uint256).max);
        }
    }

    function _logIdle(CrownWhaleHarvest h, bytes32 id, string memory tag) internal view {
        console2.log(tag);
        console2.logBytes32(id);
        console2.log("idle", h.idleOf(id));
    }
}
