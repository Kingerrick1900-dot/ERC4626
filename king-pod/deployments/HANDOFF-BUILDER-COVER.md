# HANDOFF TO BUILDER

**King's Protection · Oracle Boundary · Cover Phase**  
**Mode:** LAW · ZK + Quantum · PR [#195](https://github.com/Kingerrick1900-dot/ERC4626/pull/195)  
**Predecessor:** `HANDOFF-KINGS-COMBINED-PLAN.md` · `FIRE-KINGS-COMBINED.md` (matched fired)

---

## The Doctrine (Non-Negotiable)

| Rule | Enforcement |
|--|--|
| ZK on every fire | `ZK_SHIELD=1` mandatory |
| No transparent path | `TRANSPARENT_OK=0` · `NO_ZK=0` or script abort |
| Quantum signing | RSS rails + gate approvals (WalletGate attestations) |
| Proven King | `zkGate.isProven(HOT)` on every fire |
| Speed | **No exception** |

Fire scripts: `script/FireKingsCombined.s.sol` · `script/FireKingsOrder.s.sol` · `script/FireCrownGateV2.s.sol`

---

## The King's Protection (Priority 1)

**Goal:** Separate **sovereign authority** (cold) from **operational wallet** (HOT). HOT keeps `operator` for sized moves only.

| Step | Action | Contract / call | Status |
|--|--|--|--|
| 1 | **Landing** = cold sovereign wallet | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` | ✅ Recorded |
| 2 | `initiateKingTransfer(Landing)` | `CrownGateV2` @ `0x76fa…` · HOT signed | ✅ **Live** · `FIRE-KING-ROTATE.md` |
| 3 | `acceptKingship()` from **Landing** | `pendingKing == Landing` | ⏳ Pending Landing key |
| 4 | HOT **operator only** on gate | `setOperator(HOT, true)` from Landing after accept | ⏳ Pending |
| 5 | Kill switch drill | `setPaused(true)` → `supplyCollateral` / `borrowUSDC` **revert `IsPaused`** → `setPaused(false)` | Fork **PASS** (`test_live_gate_kill_switch`) · mainnet drill ⏳ |
| 6 | Approval hygiene | `resetApprovals()` after every borrow/repay cycle | ⏳ Pending |

**References:** `src/CrownGateV2.sol` — `initiateKingTransfer`, `acceptKingship`, `setPaused`, `resetApprovals`.

**Fork test (builder):**

```bash
cd king-pod
forge test --match-test test_live_gate_kill_switch -vv
```

**Mainnet drill (King cold after rotate, or HOT until step 3 done):**

```bash
# pause → confirm revert on borrow → unpause
cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b "setPaused(bool)" true --rpc-url "$BASE_RPC_URL" --private-key "$KING_KEY"
cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b "setPaused(bool)" false --rpc-url "$BASE_RPC_URL" --private-key "$KING_KEY"
```

---

## The Oracle Boundary (Priority 2)

**Rule:** `CrownOracle` applies **only** to the sovereign RSS/USDC book. External Morpho markets keep **neutral** third-party oracles — no sovereign price leakage.

| Market | Id (prefix) | Oracle (live Base) | Role |
|--|--|--|--|
| **Sovereign RSS/USDC** | `0x1293…2f7b` | `0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d` · **CrownOracle** · King `setPrice` | Kingdom collateral book |
| **cbBTC/USDC (idle)** | `0x9103…1836` | `0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9` · external Morpho oracle (BTC/USD path) | Idle liquidity · **not** RSS |

**Live verify (handoff refresh):**

```bash
cast call 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb \
  "idToMarketParams(bytes32)(address,address,address,address,uint256)" \
  0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836 \
  --rpc-url "$BASE_RPC_URL"
```

| Check | Result |
|--|--|
| Sovereign uses CrownOracle | **Yes** · $50k RSS (Morpho scale `5e28`) |
| cbBTC book uses CrownOracle | **No** |
| Contamination risk | **None** — oracle boundary holds |

Detail: `HANDOFF-SOVEREIGN-ORACLE.md` · `VERIFY-CBBTC-IDLE.md`

---

## The Cover Phase (Priority 3)

**State:** Engine idling on **matched** fire (~$2M Morpho LP on CombinedFire). HOT USDC ~**$0** — cover not landed.

| Item | Value |
|--|--|
| CombinedFire | `0x37C9b6f79cA311B40083363Eb231E62B980Fa646` |
| Trigger | `fireWithCover()` · HOT USDC **≥ $2,000,000** + `USDC.approve(fire, max)` |
| Script | `FIRE_KINGS_COMBINED=1 ZK_SHIELD=1 MODE=cover` · `script/FireKingsCombined.s.sol` |
| Outcome | **Engine** → `CrownZkYieldLadder` (Steak 60% / Gauntlet 40%) · **Reserve** → HOT |

### Cover paths (doctrine-locked)

| Path | Mechanism | Status |
|--|--|--|
| **1** | Draw more credit vs 222K RSS @ sovereign gate (LTV ~0.03%) | ⏸️ **Paused** — no doctrine bypass for speed |
| **2** | Tap cbBTC idle (`0x9103…`) via flash-seed | ⏸️ **Paused** — requires real cbBTC / foreign PA, not stub flash |
| **3** | **Signed LP** — inbound memo → LP settles USDC to HOT → `fireWithCover` | ✅ **Recommended** |
| **4** | **Spoils** — `CrownSpoilsOfWar` 30/50/20 (`0x4dBc…ecd0`) accumulates HOT leg | ✅ Slow path |

Path 3 memo draft: `deployments/MEMO-INBOUND-SIGNED-LP-COVER.md`

---

## The Builder's Checklist

1. **Rotate** King key to cold (`initiateKingTransfer` → cold `acceptKingship`).
2. **Test** kill switch on fork (`test_live_gate_kill_switch`) then mainnet drill.
3. **Confirm** oracle boundary (commands above · sovereign vs `0x9103…`).
4. **Draft / circulate** inbound memo for signed LP (Path 3).
5. **Execute** `fireWithCover` once HOT holds ≥ $2M USDC under `ZK_SHIELD=1`.

---

## Live anchors (do not drift)

| Role | Address |
|--|--|
| HOT (operational) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| CrownGateV2 | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| WalletGate (ZK) | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` |
| CrownKingsCombinedFire | `0x37C9b6f79cA311B40083363Eb231E62B980Fa646` |
| Sovereign market | `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b` |
| Morpho Blue | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |

```
HANDOFF=BUILDER_COVER
ZK_SHIELD=MANDATORY
KING_PROTECTION=P1
ORACLE_BOUNDARY=P2
COVER_PHASE=P3
COMBINED_FIRE=0x37C9b6f79cA311B40083363Eb231E62B980Fa646
COVER_TRIGGER=2000000e6
MODE=cover
PR=195
```
