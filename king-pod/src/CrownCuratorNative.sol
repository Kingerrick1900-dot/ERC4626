// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IEusdMintN {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

interface IBordersN {
    function bordersSecure() external view returns (bool);
}

interface IPqN {
    function activeDilithium() external view returns (bytes32);
}

interface ICapacityN {
    function canMint(uint256 amount) external view returns (bool);
    function unlockTranche(uint256 amount, bytes32 navRoot) external;
}

interface IOceanN {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function asset() external view returns (address);
}

/// @title CrownCuratorNative
/// @notice Kingdom-owned eUSD vault (MetaMorpho-class). No Circle. King is curator.
/// @dev Allocates across Ocean / Pendle sleeve / Aave-class yield sleeve. Mint via NFC+PQ+borders.
contract CrownCuratorNative is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant MINT_CAP_SLICE = 200_000_000 ether; // 200M eUSD
    uint256 public constant BPS = 10_000;

    IERC20 public immutable eusd;
    address public immutable hot;
    address public attest;
    address public pq;
    address public capacity;
    address public ocean; // CrownBammOcean or ERC4626-like
    address public pendleSleeve; // eUSD park / PT adapter
    address public aaveSleeve; // yield sleeve (USDC Aave after exit, or eUSD park)

    uint16 public oceanBps = 5000;
    uint16 public pendleBps = 2500;
    uint16 public aaveBps = 2500;

    uint256 public totalMinted;
    uint256 public totalShares;
    mapping(address => uint256) public balanceOf;
    mapping(bytes32 => bool) public nfcUsed;

    bool public requireBorders = true;
    bool public requirePq = true;
    bool public armed;

    event Armed(bool on);
    event MintDeposited(address indexed to, uint256 eusdAmt, uint256 shares, bytes32 nfc);
    event Allocated(uint256 toOcean, uint256 toPendle, uint256 toAave);
    event Harvested(uint256 amt, address to);
    event StrategiesSet(address ocean, address pendle, address aave);

    error Auth();
    error Borders();
    error Pq();
    error Cap();
    error Bad();
    error Nfc();
    error Disarmed();
    error Minter();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(address eusd_, address hot_, address owner_) Ownable(owner_) {
        eusd = IERC20(eusd_);
        hot = hot_;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setArmor(address attest_, address pq_, address capacity_) external onlyOwner {
        attest = attest_;
        pq = pq_;
        capacity = capacity_;
    }

    function setStrategies(address ocean_, address pendle_, address aave_) external onlyOwner {
        ocean = ocean_;
        pendleSleeve = pendle_;
        aaveSleeve = aave_;
        emit StrategiesSet(ocean_, pendle_, aave_);
    }

    function setWeights(uint16 o, uint16 p, uint16 a) external onlyOwner {
        if (uint256(o) + p + a != BPS) revert Bad();
        oceanBps = o;
        pendleBps = p;
        aaveBps = a;
    }

    function asset() external view returns (address) {
        return address(eusd);
    }

    function totalAssets() public view returns (uint256) {
        return eusd.balanceOf(address(this));
    }

    /// @notice NFC tap → mint eUSD (capacity-gated) → vault shares. Quantum Dilithium active required.
    function nfcMintAndDeposit(uint256 eusdAmt, bytes32 nfcReceipt, bytes32 navRoot)
        external
        onlyHot
        nonReentrant
        returns (uint256 shares)
    {
        if (!armed) revert Disarmed();
        if (eusdAmt == 0 || nfcReceipt == bytes32(0)) revert Bad();
        if (nfcUsed[nfcReceipt]) revert Nfc();
        _gate();
        if (totalMinted + eusdAmt > MINT_CAP_SLICE) revert Cap();
        if (!IEusdMintN(address(eusd)).isMinter(address(this)) && !IEusdMintN(address(eusd)).isMinter(hot)) {
            revert Minter();
        }
        if (capacity != address(0) && !ICapacityN(capacity).canMint(eusdAmt)) revert Cap();

        nfcUsed[nfcReceipt] = true;

        // Mint to this vault (if vault is minter) else hot mints then pulls — prefer vault minter
        if (IEusdMintN(address(eusd)).isMinter(address(this))) {
            IEusdMintN(address(eusd)).mint(address(this), eusdAmt);
        } else {
            // Hot path: mint to hot then transferIn — caller must be hot with allowance path
            IEusdMintN(address(eusd)).mint(hot, eusdAmt);
            eusd.safeTransferFrom(hot, address(this), eusdAmt);
        }

        shares = eusdAmt; // 1:1 bootstrap
        totalShares += shares;
        balanceOf[hot] += shares;
        totalMinted += eusdAmt;
        emit MintDeposited(hot, eusdAmt, shares, nfcReceipt);
        navRoot; // kept for capacity/attest correlation
    }

    /// @notice Deposit existing eUSD (no mint).
    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (assets == 0 || receiver == address(0)) revert Bad();
        eusd.safeTransferFrom(msg.sender, address(this), assets);
        shares = assets;
        totalShares += shares;
        balanceOf[receiver] += shares;
    }

    /// @notice Route idle eUSD across Ocean / Pendle / Aave-class sleeves.
    function allocate() external onlyHot nonReentrant {
        uint256 bal = eusd.balanceOf(address(this));
        if (bal == 0) revert Bad();
        uint256 toO = (bal * oceanBps) / BPS;
        uint256 toP = (bal * pendleBps) / BPS;
        uint256 toA = bal - toO - toP;

        if (toO > 0 && ocean != address(0)) {
            eusd.safeApprove(ocean, toO);
            // Ocean may be BAMM non-4626 — try deposit, else leave approved pull
            try IOceanN(ocean).deposit(toO, address(this)) {} catch {
                eusd.safeTransfer(ocean, toO);
            }
        }
        if (toP > 0 && pendleSleeve != address(0)) {
            eusd.safeTransfer(pendleSleeve, toP);
        }
        if (toA > 0 && aaveSleeve != address(0)) {
            eusd.safeTransfer(aaveSleeve, toA);
        }
        emit Allocated(toO, toP, toA);
    }

    function harvestTo(address to, uint256 amt) external onlyHot nonReentrant {
        if (to == address(0)) revert Bad();
        uint256 bal = eusd.balanceOf(address(this));
        uint256 send = amt == 0 || amt > bal ? bal : amt;
        if (send == 0) revert Bad();
        eusd.safeTransfer(to, send);
        emit Harvested(send, to);
    }

    function _gate() internal view {
        if (requireBorders && attest != address(0) && !IBordersN(attest).bordersSecure()) revert Borders();
        if (requirePq && pq != address(0) && IPqN(pq).activeDilithium() == bytes32(0)) revert Pq();
    }
}
