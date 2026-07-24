// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
}

/// @notice Permissionless Morpho Blue USDC supply → opens idle for ops borrow.
/// @dev No Gauntlet gate. KING_GO=1 FIRE_MORPHO_SUPPLY=1 SUPPLY_USDC=<raw6>
contract FireMorphoBlueSupply is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MORPHO_SUPPLY", uint256(0)) == 1, "NEED FIRE_MORPHO_SUPPLY=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 amt = vm.envUint("SUPPLY_USDC");
        require(amt > 0, "AMT");
        require(IERC20S(USDC).balanceOf(HOT) >= amt, "NO_USDC");

        IMorphoS.MarketParams memory mp = IMorphoS.MarketParams({
            loanToken: USDC,
            collateralToken: ELEPAN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (uint128 s0,, uint128 b0,,,) = IMorphoS(MORPHO).market(ELE_USDC);
        uint256 idleBefore = uint256(s0) - uint256(b0);

        vm.startBroadcast(pk);
        IERC20S(USDC).approve(MORPHO, amt);
        IMorphoS(MORPHO).supply(mp, amt, 0, HOT, "");
        vm.stopBroadcast();

        (uint128 s1,, uint128 b1,,,) = IMorphoS(MORPHO).market(ELE_USDC);
        uint256 idleAfter = uint256(s1) - uint256(b1);
        require(idleAfter >= idleBefore + amt, "IDLE_MISS");
        console2.log("supplied", amt);
        console2.log("idleBefore", idleBefore);
        console2.log("idleAfter", idleAfter);
        console2.log("BLUE_SUPPLY_OK", uint256(1));
    }
}
