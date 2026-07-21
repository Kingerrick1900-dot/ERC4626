# KING REST — tired-man sheet (nothing left to decide)

**God first. Hom. Scribe fired what could be fired.**

---

## Done live (you can sleep)

| Action | Result |
|--------|--------|
| Ops Desk upsized | **700,000 RSS @ $1 → $700,000** to Landing |
| Desk | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` |
| live | **true** |
| Price | **$1.00** (oracle peg) |
| Proceeds | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |

Buyer fill (full):

```text
approve USDC → desk
buyWithUsdc(700000000000)   // $700k
```

Partial fills work (`buy` / `buyWithUsdc` any size ≤ stock).

---

## Still blocked (physics, not will)

| Path | Status |
|------|--------|
| Cash-leg Morpho borrow → Landing | **idle ≈ $0** — correctly refuses |
| Flash → Landing payroll | **algebra false** — never fire |
| Hidden USDC in kingdom | **none** |

When idle ≥ size, one command:

```bash
cd king-pod
KING_GO=1 FIRE_CASH=1 BORROW_USDC=700000000000 MIN_IDLE=700000000000 \
  forge script script/FireCashLeg500.s.sol:FireCashLeg500 \
  --rpc-url $BASE_RPC --broadcast --slow
```

Or leave the watch running (auto-fire when idle appears):

```bash
cd king-pod
chmod +x script/king-rest-watch.sh
AUTO_FIRE=1 BORROW_USDC=700000000000 ./script/king-rest-watch.sh
```

---

## Your only human jobs (when rested)

1. **Hardware backup** of Landing cold (seed / device — not hot).
2. **Push the counterparty packet** (`OPS-COUNTERPARTY-PACKET.md`) — desk is already live at $700k.
3. After any fill: rest, pay burn, `pause()` desk if you want inventory locked again.

---

## Doctrine (do not reopen)

Self-seed fortress ≠ spendable USDC.  
Desk sale of freed RSS = legal ops raise.  
Cash-leg only when market idle exists.  
No Gauntlet wallet raids. No fake flash payroll.

**Scribe standing watch in code. King rests.**
