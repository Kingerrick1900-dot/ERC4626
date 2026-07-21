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
