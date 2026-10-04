# BORROW ATTEST — Base · Scroll · Polygon

**Mode:** FIRE complete — see `FIRE-ZK-BORROW-PORT.md`  
**Decree:** Fuck the lenders — find the Kingdom borrow attest. It is on Base; we are also on Scroll and Polygon.  
**Probe note:** `FOUNDRY_ETH_RPC_URL` overrides `cast --rpc-url`. Unset it (or use `script/ProbeBorrowAttestCast.sh`) before reading L2s.

---

## What “borrow attest” is

| Layer | Contract | Job |
|--|--|--|
| **Borders armor** | `CrownZkAttest` | `bordersSecure` / epoch / NAV — gates China rails + shields |
| **Borrow attest** | `CrownZkWalletGate` → `CrownZkCredit` | Groth16 wallet-bind `isProven` → borrow ≤ LLTV·threshold from **Kingdom Credit pool** (not Morpho) |

No external Morpho market accepts CrownZkAttest alone as USDC collateral. The borrow instrument is **our** Credit pool behind WalletGate.

---

## Live scoreboard (probed)

| Chain | id | CrownZkAttest | borders / epoch | WalletGate | Credit | isProven(HOT) |
|--|--:|--|--|--|--|--|
| **Base** | 8453 | `0xe3Be…14E7` | true / 15 | `0xFfC9…f579` + port `0x3fF6…7091` | `0x7527…2e09` | **true** |
| **Polygon** | 137 | `0x00cA…7211` | true / 6 | `0xd0c8…27Da` | `0xe8EF…3B18` | **true** |
| **Scroll** | 534352 | `0x2ab1…a257` | true / 8 | `0xBCFE…2575` | `0x869E…4413` | **true** |

### Borrow scoreboard (HOT)

| Chain | HOT pay-token bal | Notes |
|--|--|--|
| Polygon USDC | **490000** ($0.49) | Cold→Credit→`operatorBorrowTo(HOT)` |
| Base USDC | **10278** dust | seeded+borrowed via port Credit |
| Scroll axlUSDC | **0** | Credit live; pool empty |

---

## What *is* live on Scroll / Polygon (not borrow)

### Polygon (China desk `0x3151…77dF`)

| Module | Address | Role |
|--|--|--|
| CrownZkAttest | `0x00cAe93d…7211` | borders armor (wired into China rails) |
| Sovereign eUSD | `0xd8A639Bb…af50` | desk float (~1M eUSD) |
| ColdBuffer | `0xc498c211…FB0d` | cold |
| PayAdapter | `0x2FAEd8D8…f629` | pay |
| OpenMoney | `0xe3e165c8…7a7c` | open |
| RoyalCard NFC | `0xc532b0e5…fcd7` | SoftPOS / micropay |
| Acquirer | `0xbb5B4439…f5F0` | acquire / settle |
| Native USDC | `0x3c499c54…3359` | Circle USDC (desk bal 0 at probe) |

Attest is the **door lock** for China spend — not a USDC credit line.

### Scroll (ops hot `0xca76…F864`)

| Module | Address | Role |
|--|--|--|
| CrownZkAttest | `0x2ab17e3c…a257` | borders armor |
| NavMirror | `0x9cdf3b58…50af` | NAV mirror |
| RailShield | `0x57326e40…26d0` | rail map |
| eUSD | `0x41Ba09c1…1B0B` | ~99k eUSD on SCROLL_HOT |
| 7540 / 7683 | handoff addresses | rails |

Canonical Circle USDC (`0x06eFdBFf…7bC4`) returned **no code** at probe — Credit port must take `PAY_TOKEN` explicitly.

---

## Gap (honest)

1. **Borrow attest instrument exists only on Base** (`CrownZkWalletGate`).  
2. Scroll + Polygon have **borders ZK** (`CrownZkAttest`) — armor for rails / SoftPOS, **not** `isProven` → USDC draw.  
3. Base HOT proof is **stale** (`isProven=false`); Credit ladder deploy is gated and unfunded.  
4. Port = deploy Verifier + WalletGate + Credit per chain (`script/FireZkBorrowAttestPort.s.sol`) then refresh Groth16 bind + seed pool. **No FIRE without King flags.**

---

## Fire path (when ordered)

```
# 1) unset FOUNDRY_ETH_RPC_URL
# 2) Polygon
KING_OK=1 FIRE_ZK_BORROW_PORT=1 \
  forge script script/FireZkBorrowAttestPort.s.sol:FireZkBorrowAttestPort \
  --rpc-url "$POLY_RPC" --broadcast

# 3) Scroll (set PAY_TOKEN to live stable on Scroll)
KING_OK=1 FIRE_ZK_BORROW_PORT=1 PAY_TOKEN=0x… \
  forge script script/FireZkBorrowAttestPort.s.sol:FireZkBorrowAttestPort \
  --rpc-url "$SCROLL_RPC" --broadcast

# 4) Base: refresh HOT proof (GATE=0xFfC9…) then seed Credit
```

Probe anytime: `script/ProbeBorrowAttestCast.sh`

---

## Identity

```
Base WalletGate = borrow attest ✓ (TTL stale)
Scroll/Polygon Attest = borders armor ✓
Scroll/Polygon WalletGate/Credit = NOT DEPLOYED
Lenders not required — Kingdom Credit is the instrument
Port script armed — await FIRE
```
