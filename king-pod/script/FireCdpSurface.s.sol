// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
}

interface ICdpC {
    function maxWithdrawable() external view returns (uint256);
    function maxMintable() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function withdraw(uint256 amount) external;
    function mintTo(address to, uint256 amount) external;
    function repay(uint256 amount) external;
}

/// @notice CDP surface: withdraw Elepan and/or mint eUSD to Landing.
/// @dev Fork-proven at live maxWithdrawable / maxMintable.
///      KING_GO=1 FIRE_CDP=1
///      MODE=withdraw | mint | both  (default both)
contract FireCdpSurface is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CDP = 0x46b1D159b3a2694e7b70F550b7d5dEf6df451174;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CDP", uint256(0)) == 1, "NEED FIRE_CDP=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        string memory mode = vm.envOr("MODE", string("both"));
        bool doWithdraw = _eq(mode, "withdraw") || _eq(mode, "both");
        bool doMint = _eq(mode, "mint") || _eq(mode, "both");

        // Mint before withdraw so MODE=both keeps HF room (max withdraw pins HF≈1.55).
        uint256 maxM = ICdpC(CDP).maxMintable();
        uint256 mintAmt = vm.envOr("MINT_EUSD", doMint && doWithdraw ? maxM / 2 : maxM);
        if (doMint) require(mintAmt > 0 && mintAmt <= maxM, "MINT_SIZE");

        uint256 eleBefore = IERC20C(ELEPAN).balanceOf(HOT);
        uint256 eusdBefore = IERC20C(EUSD).balanceOf(LANDING);

        vm.startBroadcast(pk);
        if (doMint) ICdpC(CDP).mintTo(LANDING, mintAmt);

        uint256 maxW = ICdpC(CDP).maxWithdrawable();
        uint256 pull = vm.envOr("WITHDRAW_ELEPAN", doMint && doWithdraw ? maxW / 2 : maxW);
        if (doWithdraw) require(pull > 0 && pull <= maxW, "WITHDRAW_SIZE");
        if (doWithdraw) ICdpC(CDP).withdraw(pull);
        vm.stopBroadcast();

        console2.log("hf", ICdpC(CDP).healthFactor());
        console2.log("withdrawnElepan", doWithdraw ? pull : 0);
        console2.log("mintedEusd", doMint ? mintAmt : 0);
        console2.log("hotElepan", IERC20C(ELEPAN).balanceOf(HOT));
        console2.log("landingEusd", IERC20C(EUSD).balanceOf(LANDING));
        console2.log(
            "CDP_SURFACE_OK",
            (!doWithdraw || IERC20C(ELEPAN).balanceOf(HOT) >= eleBefore + pull)
                    && (!doMint || IERC20C(EUSD).balanceOf(LANDING) >= eusdBefore + mintAmt)
                ? uint256(1)
                : uint256(0)
        );
    }

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
