// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IBorders {
    function bordersSecure() external view returns (bool);
}

interface IERC20Supply {
    function totalSupply() external view returns (uint256);
}

/// @title CrownAmericaCapacity
/// @notice Operation America — mint CAPACITY registry. Does not mint.
/// @dev Ceiling can be 100T eUSD units. Actual mint stays on eUSD minter under King GO.
contract CrownAmericaCapacity is Ownable {
    IERC20Supply public immutable eusd;
    address public attest; // ZkAttest borders gate for capacity raises
    uint256 public mintCapacity; // eUSD 18dp ceiling
    uint256 public trancheSize; // optional step size (0 = uncapped steps within capacity)
    uint256 public unlockedCapacity; // portion of ceiling unlocked by tranche GOs
    bytes32 public lastNavRoot;

    event CapacitySet(uint256 capacity, bytes32 navRoot);
    event TrancheUnlocked(uint256 unlockedCapacity, uint256 trancheSize, bytes32 navRoot);
    event AttestSet(address attest);
    event NavRootSet(bytes32 navRoot);

    error Borders();
    error Cap();
    error Zero();

    constructor(address eusd_, address owner_, uint256 initialCapacity) Ownable(owner_) {
        if (eusd_ == address(0)) revert Zero();
        eusd = IERC20Supply(eusd_);
        mintCapacity = initialCapacity;
        unlockedCapacity = 0; // unlock via tranche — capacity exists, mint not enabled until unlock
        emit CapacitySet(initialCapacity, bytes32(0));
    }

    function setAttest(address a) external onlyOwner {
        attest = a;
        emit AttestSet(a);
    }

    /// @notice Set absolute ceiling (e.g. 100 trillion eUSD). Does not mint.
    function setCapacity(uint256 capacity, bytes32 navRoot) external onlyOwner {
        _borders();
        if (capacity < eusd.totalSupply()) revert Cap();
        mintCapacity = capacity;
        lastNavRoot = navRoot;
        emit CapacitySet(capacity, navRoot);
        emit NavRootSet(navRoot);
    }

    /// @notice Unlock a tranche of headroom for future mints (still does not mint).
    function unlockTranche(uint256 amount, bytes32 navRoot) external onlyOwner {
        _borders();
        if (amount == 0) revert Zero();
        uint256 next = unlockedCapacity + amount;
        if (next > mintCapacity) revert Cap();
        unlockedCapacity = next;
        trancheSize = amount;
        lastNavRoot = navRoot;
        emit TrancheUnlocked(unlockedCapacity, amount, navRoot);
        emit NavRootSet(navRoot);
    }

    function minted() public view returns (uint256) {
        return eusd.totalSupply();
    }

    function headroomCapacity() public view returns (uint256) {
        uint256 m = minted();
        return mintCapacity > m ? mintCapacity - m : 0;
    }

    function headroomUnlocked() public view returns (uint256) {
        uint256 m = minted();
        return unlockedCapacity > m ? unlockedCapacity - m : 0;
    }

    /// @notice Policy check for future minters — unlocked headroom only.
    function canMint(uint256 amount) external view returns (bool) {
        if (amount == 0) return false;
        if (attest != address(0) && !IBorders(attest).bordersSecure()) return false;
        return amount <= headroomUnlocked();
    }

    function _borders() internal view {
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
    }
}
