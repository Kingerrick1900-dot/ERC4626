# FIRE — Idle into live RSS book + yRSS unlock

**Mode:** FIRE · Base  
**Machine:** RSS USDC Morpho market `0x41c0…7d88` · oracle **$1200** · LLTV 77%  
**King position:** **252,000 RSS** collateral · live borrow book · yRSS curator vault behind it

---

## What we engineered

The live PoD book was at full utilization. King still holds the RSS collateral and the borrow. Idle was forced back into that book, which unlocked yRSS withdraw to HOT.

| Step | Action | Tx |
|--|--|--|
| 1 | Sold BRETT → USDC | [`0xaf3a0e00…4f7d`](https://basescan.org/tx/0xaf3a0e009787ea8d2e30a19ccfab5f965e586484c57c224a8169333ad8004f7d) |
| 2 | Supplied USDC into live RSS/$1200 market (created idle) | [`0x49a98870…aa7e`](https://basescan.org/tx/0x49a988701a004b117b4b0e764c977dd806c10c2ea89dd18f348ecf81695faa7e) |
| 3 | yRSS `maxWithdraw` opened → withdrew to HOT | [`0xef0d3b6e…3468`](https://basescan.org/tx/0xef0d3b6ef37749aad94dc65d26300cef500ad89c6cca6781e97adc8a78de3468) |

Script: `script/FireIdleUnlockYrss.s.sol` · gate `FIRE_IDLE_UNLOCK=1`

---

## Live machine (not a zero story)

| Piece | State |
|--|--|
| RSS collateral posted | **252,000 RSS** @ **$1200** oracle |
| Collateral value | **~$302.4M** |
| yRSS | King-curated MetaMorpho · ~99.95% King-owned |
| Unlock law | Seed USDC idle into `0x41c0…` → yRSS can pay HOT |

---

## Scale path

1. More USDC into market `0x41c0…` (bridge Poly HOT USDC, DeepPull sweep, external LP, foreign PA).  
2. Each seeded unit re-opens yRSS withdraw.  
3. Foreign PA: Gauntlet Frontier holds idle on Morpho idle-market `0x38c8…` — needs their curator to open `maxIn` into `0x41c0…`.  
4. yRSS already has PA `maxIn` **$5M** into both RSS books — door is on our side.

```
IDLE_UNLOCK=PROVED
MARKET=0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
COLLATERAL_RSS=252000
ORACLE_USD=1200
HOT_USDC_BASE=328834
NEXT=size_seed→yRSS_unlock→foreign_PA_maxIn
```
