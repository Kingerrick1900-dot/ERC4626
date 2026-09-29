# FREEZE — CN Desk Atomic USDC Ingress

**Mode:** FREEZE · no builds  
**Desk:** Chinese crypto-engineer playbook · buying-power first  

---

## 120-word plan (refined)

King is right: PSM is a contract, not a prayer. CN desk chase **atomic USDC**, not more eUSD theater.

**Fix the three plays:** (1) Maker-style flash PSM fill only works if a live PSM **accepts** USDT/USDC and the repay leg closes on Curve/Aero **without** inventing Circle dollars—Crown must flash-borrow **real** USDT/USDC, `sellGem`/`buyGem` against `0x064489…` / Base multi-PSM `0xF733…`, repay same tx. (2) CDP mint-vs-premium is not “fill PSM”; it deepens eUSD supply. Use only when eUSD trades **>\$1** and collateral is **outside USDC already owned**—never mint against hope. (3) Ethena DN on RSS is **blocked** by law: loan ≠ sell gold; yield-to-cold cannot bootstrap PSM from RSS.

**Build next (not now):** `CrownPSMFiller` — flash USDT/USDC only; AxCNH later if gem exists; dry-run on Base fork; kill if no positive USDC delta to Landing/HOT.

---

## Kill / go gates

| Gate | Rule |
|--|--|
| GO | Fork sim shows Landing/HOT **USDC ↑**, flash repaid, gas covered |
| KILL | Path needs eUSD-as-cash, RSS sell, or missing PSM gem |
| NO | Capacity narrative · AxCNH without listed gem · DN-on-gold |

```
FREEZE=cn-psm-atomic
YES=flash-USDT/USDC→live-PSM→USDC-delta
NO=eUSD-theater · RSS-DN · AxCNH-fantasy
BUILD=later CrownPSMFiller · fork-first
```
