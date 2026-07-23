# ELEPAN CURATOR ALLOCATION + LOAN ACCESS — VERDICT (NO FIRE)

**Question:** Can we curate allocations with no depth? Full or partial access on loans?  
**Answer:** **Yes — allocation curation is live today at TVL≈0.** Loan *permission* on Morpho Blue is always open; loan *liquidity* and vault *deposit* access are what you curate (full or partial).

**No role/gate changes in this note.** Configure only on King GO.

---

## Critical split (screenshot mix-up)

| Surface | What it is | Gates (KYC/allowlist)? | Allocation controls |
|--|--|--|--|
| **yELEPAN-USDC** `0x61bf…145E` | **MetaMorpho** (V1 vault) | **No** four V2 gates | Curator / Allocator / Guardian / caps / queue / PA |
| **Vault V2 WETH** `0x35a0…Ddb2` | **Morpho Vault V2** | **Yes** — receive/send shares+assets gates | Curator / Allocator / Sentinel / adapters / abs+rel caps |
| **Morpho Blue markets** (Elepan/USDC, WETH, cbBTC) | Isolated books | **No** — borrow is permissionless | Idle depth only (LLTV/oracle/IRM immutable per market) |

yELEPAN-USDC Curator + Allocator tabs = MetaMorpho roles (already set).  
V2 Gate / Sentinel model = the WETH Vault V2 (and any future USDC V2), **not** MetaMorpho.

---

## On-chain today (depth not required — already true)

### yELEPAN-USDC (TVL = **0**, fully curatable)
| Control | Live value |
|--|--|
| Owner / Curator | hot |
| Allocators | hot + PA `0xA090…0467` |
| Guardian | **unset** (`0x0`) |
| Timelock | **2 days** |
| Market enabled | Elepan/USDC · cap **$14M** · enabled |
| Supply queue | that market only |
| PA flow | maxIn=maxOut=**$700k** |
| Fee | 10% → Landing |

You do **not** need deposits to change caps, queue, allocators, PA flow, or fee recipient (timelock rules still apply on risk-increasing MM actions).

### Vault V2 WETH (dust TVL, gates open)
| Control | Live value |
|--|--|
| Owner / Curator | hot |
| Allocators | hot + PA = **true** |
| Sentinel (hot) | **false** (not appointed) |
| Gates (recv/send shares+assets) | all **`0x0` = permissionless / full deposit access** |
| Liquidity adapter | MorphoMarketV1 → Elepan/WETH |
| Abs/rel caps | raised to max (uint128) at bootstrap |
| Fees | 10% perf + 1%/yr mgmt → hot |

Gate setters are timelocked via `submit(bytes)` then exec — direct `setReceiveAssetsGate` reverts `DataNotTimelocked()` until submitted/elapsed (bootstrap path used `submit` + immediate exec when TL allowed).

---

## Allocation without depth — YES

Same Morpho design the note describes:

1. **Curator** sets strategy: which markets/adapters, caps, (V2) gates, risk limits.  
2. **Allocator** moves capital only inside those bounds (hot today; PA for JIT).  
3. **TVL can be zero** — rules sit ready so first depositors land inside your policy.

Already done for both yELEPAN-USDC and V2 WETH.

---

## Loans: full vs partial access (precise)

### What you **cannot** lock
Morpho Blue **borrow permission** — anyone with enough Elepan collateral can call `borrow` if the market has idle. No Curator “loan allowlist” on Blue.

### What you **can** curate (this is the real “loan access”)

| Mode | How | Effect on borrowers |
|--|--|--|
| **Full liquidity access** | Cap >0, queue on, PA maxIn &gt;0, idle in market | Anyone can borrow up to idle + PA pull |
| **Partial liquidity access** | Lower supply cap · PA maxIn/maxOut (e.g. $700k) · relative caps on V2 | Caps how much vault capital can sit in / flow into the book |
| **Starve / pause liquidity** | Cap → 0 (MM/V2 decrease) · PA maxIn=0 · deallocate | New borrow depth dries up; existing borrows remain until repay |
| **Full vault deposit access** | V2 gates = `0x0` (current) | Anyone can supply the vault that feeds loans |
| **Partial / gated deposits** | Set V2 gates (allowlist / KYC / ZK) | Only approved lenders fund the book; Blue borrow still permissionless |
| **Institutional parallel rail** | FHE v2 + ZK Elepan gate (already live) | Gated USDC in → sleeve → MM/V2; separate from Blue borrow ACL |

**“No locks on loans”** in Kingdom terms = keep Blue permissionless + keep idle/PA path funded (full or capped).  
**Partial** = use caps + PA flow + optional V2 deposit gates — not a Blue borrow blacklist.

---

## Emergency (V2 Sentinels) — available, not armed

V2 Sentinels can revoke pending timelocked actions, cut caps, deallocate — **instant** safety.  
Hot is **not** sentinel today (`isSentinel(hot)=false`). Appoint on GO if King wants that kill switch.

MetaMorpho analog: **Guardian** can revoke pending timelocked proposals — currently **unset** on yELEPAN-USDC.

---

## What you can do today without depth (checklist)

| Action | Where | Needs GO? |
|--|--|--|
| Keep / tune PA flow ($700k ↔ raise/cut) | yELEPAN-USDC + PA | Yes to change |
| Raise/lower supply cap | MetaMorpho curator | Yes (timelock on increases) |
| Appoint guardian | yELEPAN-USDC | Yes |
| Appoint V2 sentinel | Vault V2 | Yes |
| Set V2 deposit/withdraw gates | Vault V2 `submit`→exec | Yes |
| Leave loans “unlocked” | Do nothing on Blue; keep caps/PA &gt;0 | Default |
| Partial loan liquidity | Cut cap or PA maxIn | Yes |
| Gated institutional inflows | Already: ZK/FHE rail | Live |

---

## Recommendation (plan only)

1. **Allocation:** already curated at zero TVL — no blocker for M1/M2 loops.  
2. **Loans:** treat as **full borrow permission** + **partial liquidity** via $14M cap / $700k PA until King scales.  
3. **Gates:** keep V2 at `0x0` for open magnet; use **ZK/FHE rail** for KYC-style partial access rather than gating the public yVault unless King wants a private-only vault.  
4. **Safety:** on GO, set MetaMorpho **guardian** + V2 **sentinel** to hot or Landing before large external TVL.

---

## Decision ask (King)

- **Loan liquidity:** keep partial ($700k PA / $14M cap) or open wider?  
- **Deposit access:** stay full (`gates=0x0`) or arm V2 gates / stay with FHE-ZK rail only?  
- **Sentinel + Guardian:** appoint now (config only) or wait until after M1 magnet?
