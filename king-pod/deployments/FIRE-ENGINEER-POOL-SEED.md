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
| yRSS `maxWithdraw(HOT)=0` | Vault fully allocated — `seedFromYrss` waits on realloc/idle |
| `seedFromUsdc` | Primary: Kingdom USDC (Morpho-borrow / dealloc) + mint eUSD → Uni LP |
| Fork | **PASS** — pool USDC ↑, RSS unsold (`deal` = margin stand-in) |

---

## Agent arm

```
agent.exec(eng, USDC, amt, abi.encodeCall(CrownPoolEngineer.seedFromUsdc, (amt, true)))
```

---

## Tests

`PoolEngineerTest` + `PoolEngineerForkTest` **2/2 PASS**

```
FIRE=CrownPoolEngineer
PATH=seedFromUsdc (margin) · seedFromYrss when maxWithdraw>0
NO=outside-beg · RSS-sell
NEXT=realloc yRSS idle OR Morpho-borrow USDC → seedFromUsdc size
```
