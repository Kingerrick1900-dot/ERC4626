// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownGateV2} from "../CrownGateV2.sol";
import {CrownZkCredit} from "./CrownZkCredit.sol";

interface IZkGateDraw {
    function isProven(address subject) external view returns (bool);
}

/// @title CrownZkAutoDraw — sovereign Morpho + ZK Credit shielded fire
/// @notice King one-shot: Morpho borrow via CrownGateV2 and/or CrownZkCredit draw to Landing.
/// @dev Doctrine: nothing fires without ZK. Both legs revert if `zkGate.isProven(king)` is false
///      (gate enforces; credit enforces; this contract double-checks before any call).
contract CrownZkAutoDraw is Ownable, ReentrancyGuard {
    IZkGateDraw public immutable zkGate;
    CrownGateV2 public immutable morphoGate;
    CrownZkCredit public immutable credit;
    address public immutable king;
    address public immutable landing;

    event ShieldedDrawn(uint256 morphoBorrow, uint256 creditBorrow, address indexed morphoTo, address indexed creditTo);

    error KingOnly();
    error NotProven();
    error BadAmt();

    constructor(
        address zkGate_,
        address morphoGate_,
        address credit_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        if (
            zkGate_ == address(0) || morphoGate_ == address(0) || credit_ == address(0) || king_ == address(0)
                || landing_ == address(0)
        ) revert BadAmt();
        zkGate = IZkGateDraw(zkGate_);
        morphoGate = CrownGateV2(morphoGate_);
        credit = CrownZkCredit(credit_);
        king = king_;
        landing = landing_;
    }

    /// @notice Shielded fire. `morphoBorrow` → `morphoTo` (0 skips). `creditBorrow` → Landing (0 skips).
    function autoDraw(uint256 morphoBorrow, address morphoTo, uint256 creditBorrow) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (!zkGate.isProven(king)) revert NotProven();
        if (morphoBorrow == 0 && creditBorrow == 0) revert BadAmt();

        if (morphoBorrow > 0) {
            if (morphoTo == address(0)) revert BadAmt();
            morphoGate.borrowUSDC(morphoBorrow, morphoTo);
        }
        if (creditBorrow > 0) {
            credit.operatorBorrowTo(landing, creditBorrow);
        }
        emit ShieldedDrawn(morphoBorrow, creditBorrow, morphoTo, landing);
    }

    /// @notice Convenience: Morpho borrow to Landing + max Credit draw to Landing.
    function autoDrawMaxToLanding(uint256 morphoBorrow) external nonReentrant returns (uint256 creditAmt) {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (!zkGate.isProven(king)) revert NotProven();

        if (morphoBorrow > 0) {
            morphoGate.borrowUSDC(morphoBorrow, landing);
        }
        creditAmt = credit.maxBorrow(king);
        if (creditAmt > 0) {
            credit.operatorBorrowTo(landing, creditAmt);
        }
        if (morphoBorrow == 0 && creditAmt == 0) revert BadAmt();
        emit ShieldedDrawn(morphoBorrow, creditAmt, landing, landing);
    }
}
