# LIVE FIRE LAW — King Errick of Yahudah

**Rule (locked):**  
**No live deployments. No mainnet broadcasts. No new contract creates. No collateral moves. No desk changes.**  
**Unless the King explicitly says OK / GO / FIRE for that action.**

Scribe may:

- Write code, scripts, docs, packets  
- Fork / simulate / `forge test` / dry-run (`FIRE_*=0`)  
- Read chain state  

Scribe may **not** without King OK:

- `--broadcast` on Base  
- `forge create` / deploy helpers / new markets  
- `supplyCollateral` / borrow / stock / arm / pause desk  
- Spend hot gas or move RSS/USDC  

Prior live steel already on-chain stays (desk, helper, posted coll) until King orders change.  
**No further live until OK.**

## Debt law (King order — never again)

- **Debt-free means zero borrow shares on-chain.** Verified after every debt fire. Not "mostly paid." Not "dust left on purpose."
- **Never leave intentional borrow dust** (no `DUST_DEBT`, no "rounding cushion" debt, no interest-accruing residue).
- **Never call a debt job done** while Morpho still shows borrow > 0.
- **Do the job ordered.** If King says clear debt, clear debt — full stop. No pivot to other objectives.
- If chunk-unwind cannot hit zero in one contract, **chain `CrownZeroMorpho.zeroBooks()` in the same fire plan** before reporting success.
