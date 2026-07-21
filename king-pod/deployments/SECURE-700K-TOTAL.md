# Secure \$700K TOTAL — All Paths Armed

**Ask:** \$700,000 USDC. **Proof + desk live.** Pick one path or stack.

---

## LIVE credentials

| Item | Value |
|------|--------|
| ZK gate | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| `isProven(hot)` | **true** · threshold **\$700,000** |
| Proof tx | `0x356017a9f494cf0e5a1b83671e72c24b8b818d7c95bdea37248c53f3128b9e11` |
| Credit (Path B) | `0xeAE626b6e82E51c9805D72B6532A948dcf57D392` · **LLTV 100%** → full \$700k draw when funded |
| Desk (Path C) | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` · **700,000 RSS @ \$1** = **\$700,000** exact |
| Landing / cold | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Hot (subject) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

---

## Path A — OTC wire (\$700k)

1. Verify: `isProven(0x6708…a7d1) == true`  
2. Wire **700_000e6 USDC** on Base → Landing `0x5Adcea53…2357`  
3. Done. Spendable cold.

## Path B — ZK credit (\$700k)

1. Verify gate (same).  
2. `supply(700_000e6)` on credit `0xeAE626…D392`.  
3. King fires `FIRE_ZK_BORROW=1` → borrow \$700k → cold Landing.  
   Script: `FireZkBorrowToCold.s.sol`

## Path C — Desk fill (\$700k)

1. Verify desk live · `rssForSale == 700k` · `quoteUsdc(700k) == 700_000e6`.  
2. `buy(700000 ether)` or `buyWithUsdc(700000e6)` on desk.  
3. USDC → Landing same tx. Buyer receives 700k RSS.

Bond/Dutch/Whale remain extra rails (not required for the \$700k total).

---

## Counterparty one-liner

> Kingdom proves reserves ≥ \$700k on Base (`CrownZkReservesGate`). Advance \$700k USDC via Landing wire, ZK credit supply, or desk buy @ \$1 for 700k RSS. All three settle to Landing `0x5Adcea53…2357`.

## King ops after fund hits

```bash
# If Path B funded:
KING_OK=1 FIRE_ZK_BORROW=1 BORROW_AMT=700000000000 \
  forge script script/FireZkBorrowToCold.s.sol:FireZkBorrowToCold --rpc-url $BASE_RPC --broadcast
```

Verify packet: `ZK-PROOF-HOW-TO-USE.md`
