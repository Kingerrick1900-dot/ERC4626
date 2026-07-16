// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable} from "./lib/Core.sol";
import {KingSusdc} from "./KingSusdc.sol";
import {KingPair} from "./KingPair.sol";
import {KingOracle} from "./KingOracle.sol";
import {KingMoneyMarket} from "./KingMoneyMarket.sol";
import {KingPod} from "./KingPod.sol";

/// @notice Deploys full Option A stack. Owner = deployer then transferred to King.
contract KingPodFactory is Ownable {
    using SafeTransfer for IERC20;

    address public constant BALANCER = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    event Deployed(
        address sUsdc,
        address pair,
        address oracle,
        address market,
        address pod
    );

    constructor(address owner_) Ownable(owner_) {}

    function deploy(address rss, address usdc, address king) external onlyOwner returns (address pod) {
        KingSusdc sUsdc = new KingSusdc(usdc, address(this));
        KingPair pair = new KingPair(rss, address(sUsdc), address(this));
        KingOracle oracle = new KingOracle(rss, address(sUsdc), address(pair), address(this));
        // price already 0.05e18 in constructor default
        KingMoneyMarket market = new KingMoneyMarket(usdc, address(sUsdc), address(pair), address(oracle), address(this));
        KingPod kingPod = new KingPod(rss, usdc, address(sUsdc), address(pair), address(market), BALANCER, king, address(this));

        sUsdc.transferOwnership(address(market)); // market pulls USDC for borrows
        market.setOperator(address(kingPod));
        market.transferOwnership(owner);
        oracle.transferOwnership(owner);
        pair.transferOwnership(owner);
        kingPod.transferOwnership(owner);

        emit Deployed(address(sUsdc), address(pair), address(oracle), address(market), address(kingPod));
        return address(kingPod);
    }
}
