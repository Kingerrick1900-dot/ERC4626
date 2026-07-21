# FORCE FILL — Shield + Sword (Today)

**ZK = shield. Liquidity = sword. Both.**

---

## Swap target (no pool existed — creating)

| Target | Rail |
|--------|------|
| **Primary fill** | **CrownPsm** — buy kUSD with USDC @ \$1 |
| **Organic depth** | Aerodrome **stable** kUSD/USDC pool |

kUSD had **zero** DEX liquidity. Cannot swap 700k kUSD→USDC until USDC is in PSM or pool.

---

## Next counterparty (ONE ask — force this)

**Do this first:**

> Pay **USDC** into `CrownPsm.buyKusdWithUsdc(amount)` on Base.  
> Receive **kUSD 1:1**. USDC stays in PSM → King sweeps to Landing for bills.  
> Trust: ZK `isProven(hot)=true` @ \$700k (gate below). Optional.

| | |
|--|--|
| Gate (shield) | `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` (Base **EOA**) |
| Landing / bills | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Alt: Credit V2 | `0x01814e15cF01DEcdC7239b739177C36acaBaBA54` `supply` then King `borrowTo` cold |
| Alt: Desk | `0xDbf7…` 700k RSS @ \$1 |

**Bill amount:** King sets `BILL_USDC` — scribe routes first Landing USDC to ops. **Need King number** for the first wire out (CEX/bank). Until then, fill parks on Landing.

---

## After first USDC hits PSM

1. `sweepUsdcToLanding(keep)` → cold  
2. King off-ramp Landing → CEX/bank for the named bill  
3. Seed more Aero depth from fees / next fill  

---

## FIRE

```bash
KING_OK=1 FIRE_FORCE_FILL=1 forge script script/FireForceFill.s.sol:FireForceFill \
  --rpc-url $BASE_RPC --broadcast
```
