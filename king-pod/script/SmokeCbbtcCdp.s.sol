// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ICdpC {
    function deposit(uint256) external;
    function mint(uint256) external;
    function withdraw(uint256) external;
    function close() external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
}

interface IEusdC {
    function approve(address, uint256) external returns (bool);
}

/// @notice Dust smoke on cbBTC CDP with hot's remaining cbBTC (~$0.25).
contract SmokeCbbtcCdp is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CDP = 0xb7Be10165c7A3296Cb621478B3dD497c65Da28d5;

    uint256 constant MINT = 0.05 ether; // $0.05 eUSD
    uint256 constant PARTIAL = 50; // raw 8dp

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CBBTC_SMOKE", uint256(0)) == 1, "NEED FIRE_CBBTC_SMOKE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 bal = IERC20C(CBTC).balanceOf(HOT);
        console2.log("cbtcBal", bal);
        require(bal > PARTIAL, "CBTC");

        vm.startBroadcast(pk);
        IERC20C(CBTC).approve(CDP, bal);
        ICdpC(CDP).deposit(bal);
        ICdpC(CDP).mint(MINT);
        console2.log("hfAfterMint", ICdpC(CDP).healthFactor());
        ICdpC(CDP).withdraw(PARTIAL);
        console2.log("hfAfterPartial", ICdpC(CDP).healthFactor());
        require(ICdpC(CDP).healthFactor() >= ICdpC(CDP).safetyFloor(), "HF");
        IEusdC(EUSD).approve(CDP, type(uint256).max);
        ICdpC(CDP).close();
        vm.stopBroadcast();

        require(ICdpC(CDP).coll() == 0 && ICdpC(CDP).accruedDebt() == 0, "OPEN");
        console2.log("CBBTC_CDP_SMOKE_OK", uint256(1));
    }
}
