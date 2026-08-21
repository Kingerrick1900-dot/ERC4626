// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Liquity-pattern isolated CDP: lock free RSS, mint eUSD to Landing.
/// @dev Morpho books are NOT touched. No pooled lenders. No idle-USDC wait.
///      Oracle = Morpho Blue price() (1e36 scale, RSS→USDC). eUSD treated 1:1 USD.

interface IERC20RssTrove {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IKingdomEusd {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface IMorphoPrice {
    function price() external view returns (uint256);
}

contract CrownRssTrove {
    IERC20RssTrove public immutable rss;
    IKingdomEusd public immutable eusd;
    IMorphoPrice public immutable oracle;

    address public king;
    address public landing;

    /// @notice Max loan-to-value in WAD (1e18 = 100%). Default 77% matches Morpho RSS LLTV.
    uint256 public ltvWad;
    /// @notice User-set annual interest rate in WAD (Liquity V2 pattern). Stored; accrual off in v1 chassis.
    uint256 public annualRateWad;
    /// @notice Hard cap on minted eUSD outstanding from this Trove.
    uint256 public debtCeiling;

    uint256 public collateral;
    uint256 public debt;

    event Opened(uint256 collIn, uint256 minted, address indexed to);
    event Repaid(uint256 repaid, uint256 collOut);
    event Params(uint256 ltvWad, uint256 annualRateWad, uint256 debtCeiling);
    event KingUpdated(address indexed king);
    event LandingUpdated(address indexed landing);

    modifier onlyKing() {
        require(msg.sender == king, "KING");
        _;
    }

    constructor(
        address rss_,
        address eusd_,
        address oracle_,
        address king_,
        address landing_,
        uint256 ltvWad_,
        uint256 annualRateWad_,
        uint256 debtCeiling_
    ) {
        require(rss_ != address(0) && eusd_ != address(0) && oracle_ != address(0), "ZERO");
        require(king_ != address(0) && landing_ != address(0), "ZERO");
        require(ltvWad_ > 0 && ltvWad_ <= 0.91e18, "LTV");
        rss = IERC20RssTrove(rss_);
        eusd = IKingdomEusd(eusd_);
        oracle = IMorphoPrice(oracle_);
        king = king_;
        landing = landing_;
        ltvWad = ltvWad_;
        annualRateWad = annualRateWad_;
        debtCeiling = debtCeiling_;
        emit Params(ltvWad_, annualRateWad_, debtCeiling_);
    }

    /// @notice USD value of `collAmt` RSS, 18 decimals (eUSD units), via Morpho oracle.
    function collValueUsd(uint256 collAmt) public view returns (uint256) {
        // Morpho: coll * price / 1e36 = loan token raw (USDC 6dp)
        // Convert USDC-6 → 18dp: * 1e12
        uint256 usdcRaw = collAmt * oracle.price() / 1e36;
        return usdcRaw * 1e12;
    }

    function maxMintable() public view returns (uint256) {
        uint256 maxFromColl = collValueUsd(collateral) * ltvWad / 1e18;
        if (maxFromColl <= debt) return 0;
        uint256 room = maxFromColl - debt;
        if (debt >= debtCeiling) return 0;
        uint256 ceilRoom = debtCeiling - debt;
        return room < ceilRoom ? room : ceilRoom;
    }

    /// @notice Lock free RSS and mint eUSD to Landing (or `to`). Morpho untouched.
    function open(uint256 collIn, uint256 mintAmt, address to) external onlyKing {
        require(collIn > 0 && mintAmt > 0, "AMT");
        if (to == address(0)) to = landing;

        require(rss.transferFrom(msg.sender, address(this), collIn), "PULL");
        collateral += collIn;
        debt += mintAmt;

        require(debt <= debtCeiling, "CEIL");
        uint256 maxDebt = collValueUsd(collateral) * ltvWad / 1e18;
        require(debt <= maxDebt, "LTV");

        eusd.mint(to, mintAmt);
        emit Opened(collIn, mintAmt, to);
    }

    /// @notice Repay eUSD debt and unlock RSS to king. Optional — Morpho still untouched.
    function repay(uint256 repayAmt, uint256 collOut) external onlyKing {
        require(repayAmt > 0 && repayAmt <= debt, "DEBT");
        require(collOut <= collateral, "COLL");
        // Pull eUSD from king and burn if token supports burn(from); else transfer to sink.
        // Kingdom eUSD exposes burn(address,uint256).
        eusd.burn(msg.sender, repayAmt);
        debt -= repayAmt;
        collateral -= collOut;
        if (collateral > 0) {
            uint256 maxDebt = collValueUsd(collateral) * ltvWad / 1e18;
            require(debt <= maxDebt, "LTV");
        } else {
            require(debt == 0, "DUST");
        }
        if (collOut > 0) require(rss.transfer(king, collOut), "PUSH");
        emit Repaid(repayAmt, collOut);
    }

    function setParams(uint256 ltvWad_, uint256 annualRateWad_, uint256 debtCeiling_) external onlyKing {
        require(ltvWad_ > 0 && ltvWad_ <= 0.91e18, "LTV");
        ltvWad = ltvWad_;
        annualRateWad = annualRateWad_;
        debtCeiling = debtCeiling_;
        if (collateral > 0) {
            require(debt <= collValueUsd(collateral) * ltvWad / 1e18, "LTV");
        }
        emit Params(ltvWad_, annualRateWad_, debtCeiling_);
    }

    function setLanding(address landing_) external onlyKing {
        require(landing_ != address(0), "ZERO");
        landing = landing_;
        emit LandingUpdated(landing_);
    }

    function transferKing(address king_) external onlyKing {
        require(king_ != address(0), "ZERO");
        king = king_;
        emit KingUpdated(king_);
    }
}
