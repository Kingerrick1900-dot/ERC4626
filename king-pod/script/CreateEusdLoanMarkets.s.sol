// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoPegOracle} from "../src/MorphoPegOracle.sol";

interface IMorphoCreate {
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

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Create Morpho Blue markets: eUSD collateral × {USDC, DAI, USDbC} loan.
/// @dev Opens loan doors for kingdom eUSD. Fill comes from lenders / vault listings / self-seed.
///      KING_GO=1 PRIVATE_KEY=… forge script …:CreateEusdLoanMarkets --rpc-url $BASE_RPC_URL --broadcast --slow
contract CreateEusdLoanMarkets is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address constant USDBC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_86 = 860000000000000000; // 86%

    // Morpho price = loan wei per 1 coll wei × 1e36
    // eUSD 18 / USDC|USDbC|EURC 6 @ $1 → 1e24
    // eUSD 18 / DAI 18 @ $1 → 1e36

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        _create(USDC, 1e24, "USDC");
        _create(DAI, 1e36, "DAI");
        _create(USDBC, 1e24, "USDbC");
        _create(EURC, 1e24, "EURC");

        vm.stopBroadcast();
    }

    function _create(address loan, uint256 pegPrice, string memory tag) internal {
        MorphoPegOracle oracle = new MorphoPegOracle(pegPrice);
        IMorphoCreate.MarketParams memory mp = IMorphoCreate.MarketParams({
            loanToken: loan,
            collateralToken: EUSD,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV_86
        });
        bytes32 id = keccak256(abi.encode(mp));
        (address existingLoan,,,,) = IMorphoCreate(MORPHO).idToMarketParams(id);
        if (existingLoan != address(0)) {
            console2.log(string.concat(tag, " market already exists"));
            console2.logBytes32(id);
            return;
        }
        IMorphoCreate(MORPHO).createMarket(mp);
        console2.log(string.concat("CREATED eUSD/", tag));
        console2.log("oracle", address(oracle));
        console2.logBytes32(id);
    }
}
