# Spoils of War — $700k TEN · Long Line the King

**Spoil:** King's Morpho TEN USDC **supply** on Base  
**Market:** `0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc`  
**Oracle ($10):** `0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385` (owner = hot)  
**Hot:** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`

| Book | Live |
|--|--|
| TEN supply (spoil) | **~$700k** (king) |
| TEN borrow | **~$700k** (king) — same flash that wrote the spoil |
| Idle | **$0** until debt is repaid |
| ELE coll | ~14M (headroom at $10 / 91.5%) |
| Hot USDC | ops dust (~$60) |

The spoil is **already the King's**. It sits as Morpho supply shares. Claim moves it to the hot wallet.

---

## Claim rails

### A — Wire claim (keeps the seed on hot) ★

Desk / MM wires **≥ debt** USDC to hot → repay → withdraw supply → **~$700k on hot**.

```bash
KING_GO=1 FIRE_TEN_SPOILS=1 \
forge script script/FireTenSpoilsClaim.s.sol:FireTenSpoilsClaim \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Optional: `PULL_ELE=1` pulls all TEN collateral after claim.

Alias: `FIRE_TEN_REFANCE=1` → `FireTenRefinanceSeed.s.sol` (same machine).

### B — Free ELE (inventory spoil, debt stays)

Pull excess ELE while TEN debt stays healthy (keep ~10× min coll):

```bash
KING_GO=1 FIRE_TEN_SPOILS=1 FREE_ELE=1 CLAIM_USDC=0 \
forge script script/FireTenSpoilsClaim.s.sol:FireTenSpoilsClaim \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

### C — Flash muster (dominion proof · wallet Δ ≈ 0)

`CrownTenSpoilsWar.musterFlash` — flash repay → pull supply → repay flash → optional ELE out.  
Clears the book; does **not** leave $700k spendable (matched loop). Use when closing the facility, not for ops seed.

---

## Fork proofs

- `TenSpoilsWarForkTest::test_wire_claim_puts_700k_seed_on_hot`
- `TenSpoilsWarForkTest::test_flash_muster_clears_books_wallet_flat`
- `TenSpoilsWarForkTest::test_free_ele_keeps_debt`
- `TenRefinanceSeedForkTest` (prior)

---

## Outside doors (if wire delayed)

| Door | Need | Script / note |
|--|--|--|
| WETH/USDC PA borrow | WETH on hot | `FireExternalWethPaBorrow.s.sol` |
| Gauntlet → ELE PA | curator `maxIn` | `CURATOR-PACKET-ELE-USDC.md` / `FireCashHunt.s.sol` |
| MM ELE loan | desk USDC | `SEED-700K-PLAYS.md` |

---

## Fired

- Free ELE: `FREE-ELE-LIVE.md` — 13.23M ELE to hot, TEN $700k book kept.

## Long line

Oracle · credit book · live TEN loan · market control — the spoil was written on-chain.  
**Claim A** is the pull that puts dollars in the King's hand.
