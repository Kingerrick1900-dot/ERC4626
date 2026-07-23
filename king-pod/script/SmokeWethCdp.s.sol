// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20W {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function deposit() external payable;
}

interface ICdpW {
    function deposit(uint256) external;
    function mint(uint256) external;
    function withdraw(uint256) external;
    function close() external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
}

interface IEusdW {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Dust smoke: wrap → deposit → mint → partial withdraw → close on WETH CDP.
contract SmokeWethCdp is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CDP = 0x60033c198bb686cEA1BAAF5a5CDc7b6e3Ddc9BCF;

    uint256 constant COLL = 0.002 ether; // ~$3.85
    uint256 constant MINT = 1 ether; // $1 eUSD
    uint256 constant PARTIAL = 0.0004 ether;
    uint256 constant GAS_FLOOR = 0.002 ether;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_WETH_SMOKE", uint256(0)) == 1, "NEED FIRE_WETH_SMOKE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(HOT.balance >= COLL + GAS_FLOOR, "ETH");

        vm.startBroadcast(pk);
        IERC20W(WETH).deposit{value: COLL}();
        IERC20W(WETH).approve(CDP, COLL);
        ICdpW(CDP).deposit(COLL);
        ICdpW(CDP).mint(MINT);
        console2.log("hfAfterMint", ICdpW(CDP).healthFactor());
        ICdpW(CDP).withdraw(PARTIAL);
        console2.log("hfAfterPartial", ICdpW(CDP).healthFactor());
        require(ICdpW(CDP).healthFactor() >= ICdpW(CDP).safetyFloor(), "HF");
        IEusdW(EUSD).approve(CDP, type(uint256).max);
        ICdpW(CDP).close();
        vm.stopBroadcast();

        require(ICdpW(CDP).coll() == 0 && ICdpW(CDP).accruedDebt() == 0, "OPEN");
        console2.log("WETH_CDP_SMOKE_OK", uint256(1));
    }
}
