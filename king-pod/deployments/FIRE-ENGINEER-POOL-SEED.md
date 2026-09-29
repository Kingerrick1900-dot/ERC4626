# FIRE — Engineer eUSD/USDC pool from vault margin

**Mode:** FIRE · Base  
**Doctrine:** No outside beg. Loan ≠ sell RSS. Build market from Kingdom margin.

---

## Live

| Item | Value |
|--|--|--|
| **CrownPoolEngineer** | `0x4D42bBD373CE058959b8b2211DF4cCDa6cb3E3ff` |
| eUSD minter | granted to engineer |
| KingAgent vault | `allowedTarget=true` |
| ZkAttest | `0xe3Be837a…14E7` borders gate |

---

## Truth on rails

| Fact | Implication |
|--|--|
| yRSS `maxWithdraw(HOT)=0` | **Do not pull from yRSS** — flash loops are closed (no net USDC) |
| PARK RSS coll on HOT | **LTV maxed live** (`insufficient collateral` on borrow) · **idle ≈ $0** → seed waits on **fill/PA liquidity + margin post** |
| `seedFromUsdc` | USDC in (borrow / routed fill / credit) + mint eUSD → Uni LP · loan ≠ sell RSS |
| Macro gap | **~$1.52B idle eUSD** → external USDC via **attest · KAR · Conflux/AnchorX/SBI** — see `SCRIBE-KINGDOM-STATE.md` |
| Fork | **PASS** — engineer 2/2 · borrow-seed when idle injected (simulates PA/fill) |

---

## Fresh borrow seed (primary when idle ≥ ask)

`CrownBorrowSeed.borrowAndSeed(amt)` → Morpho `borrow(onBehalf=HOT)` → `seedFromUsdc(amt, true)`.

```bash
# Live only when PARK idle ≥ SEED_USDC (check cast market first)
SEED_USDC=500000000000 forge script script/FireBorrowSeed.s.sol:FireBorrowSeed --rpc-url $BASE_RPC_URL --broadcast
```

**Deprecated:** `CrownDeallocSeed` / yRSS flash-supply — physics block at 100% util.

---

## Agent arm

```
agent.exec(eng, USDC, amt, abi.encodeCall(CrownPoolEngineer.seedFromUsdc, (amt, true)))
```

Or deploy `CrownBorrowSeed`, authorize on Morpho, `borrowAndSeed(amt)`.

---

## Tests

| Suite | Result |
|--|--|
| `PoolEngineerTest` + fork | **2/2 PASS** |
| `BorrowSeedForkTest` | **2/2 PASS** (no-idle revert + borrow seed) |

```
FIRE=CrownPoolEngineer + CrownBorrowSeed
PATH=Morpho-borrow(HOT RSS coll) → seedFromUsdc · NOT yRSS flash
GAP=idle eUSD → external USDC (attest · KAR · routed fills)
NO=outside-beg · RSS-sell · closed-loop flash
```
