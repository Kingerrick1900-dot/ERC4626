// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IMorpho369 {
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
}

library MarketIdLib {
    function id(IMorpho369.MarketParams memory m) internal pure returns (bytes32) {
        return keccak256(abi.encode(m));
    }
}

/// @notice 3-6-9 Morpho market factory — 3 currencies × chains via fireBase3 / firePolygon3 / fireScroll3.
contract Crown369 is Ownable {
    using MarketIdLib for IMorpho369.MarketParams;

    IMorpho369 public immutable morpho;
    address public immutable rss;
    address public immutable irm;
    uint256 public immutable lltv; // 38.5e16

    address public oracle;
    address public krt;
    address public eusd;
    address public gusd;

    bytes32[3] public lastMarkets; // KRT, eUSD, gUSD

    event MarketsFired(bytes32 krtId, bytes32 eusdId, bytes32 gusdId);
    event TokensSet(address krt, address eusd, address gusd, address oracle);

    error Zero();

    constructor(
        address morpho_,
        address rss_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorpho369(morpho_);
        rss = rss_;
        irm = irm_;
        lltv = lltv_;
    }

    function setTokens(address krt_, address eusd_, address gusd_, address oracle_) external onlyOwner {
        krt = krt_;
        eusd = eusd_;
        gusd = gusd_;
        oracle = oracle_;
        emit TokensSet(krt_, eusd_, gusd_, oracle_);
    }

    function _mp(address loan) internal view returns (IMorpho369.MarketParams memory) {
        if (loan == address(0) || oracle == address(0)) revert Zero();
        return IMorpho369.MarketParams(loan, rss, oracle, irm, lltv);
    }

    function _create(address loan) internal returns (bytes32) {
        IMorpho369.MarketParams memory m = _mp(loan);
        morpho.createMarket(m);
        return m.id();
    }

    /// @notice Fire 3 markets on this chain (KRT, eUSD, gUSD vs RSS).
    function fire3() external onlyOwner returns (bytes32, bytes32, bytes32) {
        return _fire3();
    }

    function fireBase3() external onlyOwner returns (bytes32, bytes32, bytes32) {
        return _fire3();
    }

    function firePolygon3() external onlyOwner returns (bytes32, bytes32, bytes32) {
        return _fire3();
    }

    function fireScroll3() external onlyOwner returns (bytes32, bytes32, bytes32) {
        return _fire3();
    }

    function _fire3() internal returns (bytes32, bytes32, bytes32) {
        bytes32 a = krt != address(0) ? _create(krt) : bytes32(0);
        bytes32 b = eusd != address(0) ? _create(eusd) : bytes32(0);
        bytes32 c = gusd != address(0) ? _create(gusd) : bytes32(0);
        lastMarkets[0] = a;
        lastMarkets[1] = b;
        lastMarkets[2] = c;
        emit MarketsFired(a, b, c);
        return (a, b, c);
    }
}
