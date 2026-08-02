// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IVault {
    function maxWithdraw(address) external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
}

interface INpm {
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
    function ownerOf(uint256) external view returns (address);
    function decreaseLiquidity(DecreaseLiquidityParams calldata)
        external payable returns (uint256 amount0, uint256 amount1);
    function collect(CollectParams calldata) external payable returns (uint256 amount0, uint256 amount1);
    function positions(uint256) external view returns (
        uint96, address, address, address, uint24, int24, int24, uint128,
        uint256, uint256, uint128, uint128
    );
    function burn(uint256 tokenId) external payable;
}

/// @notice Own-stack cash: redeem vault dust + unwind ELE/USDC LP. No buyers. KING_GO=1 FIRE_OWN_CASH=1
contract FireOwnStackCash is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant YELEK = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    uint256 constant TOKEN_ID = 5650129;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_OWN_CASH", uint256(0)) == 1, "NEED FIRE_OWN_CASH=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        console2.log("usdcBefore", IERC20(USDC).balanceOf(HOT));
        console2.log("eleBefore", IERC20(ELE).balanceOf(HOT));

        vm.startBroadcast(pk);

        uint256 mw = IVault(YELE).maxWithdraw(HOT);
        console2.log("yeleMaxWithdraw", mw);
        if (mw > 0) IVault(YELE).withdraw(mw, HOT, HOT);

        uint256 mwk = IVault(YELEK).maxWithdraw(HOT);
        console2.log("yelekMaxWithdraw", mwk);
        if (mwk > 0) IVault(YELEK).withdraw(mwk, HOT, HOT);

        require(INpm(NPM).ownerOf(TOKEN_ID) == HOT, "NOT_NFT_OWNER");
        (,,,,,,, uint128 liq,,,,) = INpm(NPM).positions(TOKEN_ID);
        console2.log("liq", uint256(liq));
        if (liq > 0) {
            INpm(NPM).decreaseLiquidity(
                INpm.DecreaseLiquidityParams({
                    tokenId: TOKEN_ID,
                    liquidity: liq,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp + 600
                })
            );
            INpm(NPM).collect(
                INpm.CollectParams({
                    tokenId: TOKEN_ID,
                    recipient: HOT,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
        }

        vm.stopBroadcast();

        console2.log("usdcAfter", IERC20(USDC).balanceOf(HOT));
        console2.log("eleAfter", IERC20(ELE).balanceOf(HOT));
        console2.log("OWN_CASH_OK", uint256(1));
    }
}
