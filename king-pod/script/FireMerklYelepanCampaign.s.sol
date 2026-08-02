// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20M {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IMerklCreator {
    struct Campaign {
        bytes32 campaignId;
        address creator;
        address rewardToken;
        uint256 amount;
        uint32 campaignType;
        uint32 startTimestamp;
        uint32 duration;
        bytes campaignData;
    }

    function acceptConditions() external;
    function createCampaign(Campaign memory newCampaign) external returns (bytes32);
    function userSignatures(address) external view returns (bytes32);
    function messageHash() external view returns (bytes32);
    function defaultFees() external view returns (uint256);
    function rewardTokenMinAmounts(address) external view returns (uint256);
}

/// @notice Create Merkl MORPHOVAULT campaign: Elepan rewards for yELEPAN-USDC depositors.
/// @dev KING_GO=1 FIRE_MERKL=1.
///      Requires: Merkl T&Cs accepted, Elepan rewardTokenMinAmounts > 0, Elepan ≥ BUDGET on hot.
///      Merkl fee is ~3% of the reward-token amount (defaultFees / 1e9), NOT USDC.
///      Pass fresh CAMPAIGN_DATA + START_TS from Merkl encode API.
contract FireMerklYelepanCampaign is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant CREATOR = 0x8BB4C975Ff3c250e0ceEA271728547f3802B36Fd;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;

    uint256 constant BUDGET = 4_000_000e8; // 4M Elepan / 4 weeks
    uint256 constant BASE_9 = 1e9;
    uint32 constant TYPE_MORPHOVAULT = 56;
    uint32 constant DURATION = 28 days;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MERKL", uint256(0)) == 1, "NEED FIRE_MERKL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMerklCreator creator = IMerklCreator(CREATOR);
        uint256 minAmt = creator.rewardTokenMinAmounts(ELEPAN);
        require(minAmt > 0, "ELEPAN_NOT_MERKL_WHITELISTED");

        uint256 feeRate = creator.defaultFees(); // e.g. 3e7 = 3% of BASE_9
        uint256 feeElepan = (BUDGET * feeRate) / BASE_9;
        // Creator pulls full BUDGET; fee slice goes to feeRecipient in Elepan.
        require(IERC20M(ELEPAN).balanceOf(HOT) >= BUDGET, "ELEPAN_BUDGET");

        bytes memory campaignData = vm.envBytes("CAMPAIGN_DATA");
        uint32 start = uint32(vm.envUint("START_TS"));
        require(campaignData.length == 32, "CAMPAIGN_DATA_BYTES32");
        require(start > block.timestamp, "START_IN_PAST");

        // Soft min-rate check mirrors onchain: amount * HOUR >= minAmt * duration
        require(BUDGET * 3600 >= minAmt * uint256(DURATION), "REWARD_TOO_LOW_VS_MIN");

        vm.startBroadcast(pk);
        if (creator.userSignatures(HOT) != creator.messageHash()) {
            creator.acceptConditions();
        }
        IERC20M(ELEPAN).approve(CREATOR, BUDGET);

        IMerklCreator.Campaign memory c = IMerklCreator.Campaign({
            campaignId: bytes32(0),
            creator: HOT,
            rewardToken: ELEPAN,
            amount: BUDGET,
            campaignType: TYPE_MORPHOVAULT,
            startTimestamp: start,
            duration: DURATION,
            campaignData: campaignData
        });
        bytes32 id = creator.createCampaign(c);
        vm.stopBroadcast();

        console2.log("YELE", YELE);
        console2.log("BUDGET_ELEPAN", BUDGET);
        console2.log("MERKL_FEE_RATE_BASE9", feeRate);
        console2.log("MERKL_FEE_ELEPAN", feeElepan);
        console2.log("CAMPAIGN_ID");
        console2.logBytes32(id);
        console2.log("MERKL_CAMPAIGN_FIRE_OK", uint256(1));
    }
}
