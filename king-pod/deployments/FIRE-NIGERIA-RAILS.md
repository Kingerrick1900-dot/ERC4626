# FIRE — Nigeria Remittance Rails OPEN

**Mode:** FIRE · Base · LIVE  
**Doctrine:** Nigeria first. Demand before supply. 2% USDC fee → HOT.

---

## Opened

| Piece | Address |
|--|--|
| **CrownNigeriaRail** | [`0xa813cb1BF558245a1287b69b4bE6e4E43F8074F7`](https://basescan.org/address/0xa813cb1BF558245a1287b69b4bE6e4E43F8074F7) |
| `open` | **true** |
| Desk | `0x4987b70136c5C4071900C6404b3b47C34142a234` |
| HarvesterRemittance | `0xcFe3011983F713C9b132ae75540F66aACf82Ac9B` |
| KillMetric | `0x51550e85baC735c46bcd830A9122051F6Aa95440` |
| KRT / Oracle / Market | Build 3 / 2 / 4 |

Owner of rail = **Safe**. Fee sink = **HOT**. FEE_BPS = **200**.

---

## How remittance settles (ops)

1. Lagos agent KYC’d **off-chain**.  
2. Diaspora approves USDC to **Desk**.  
3. Call `desk.settleRemittance(agent, usdcAmount)`.  
4. **2%** USDC → HOT · **98%** → agent for NGN P2P.  
5. KillMetric week-1 target **$10K** USDC fees.

```
NIGERIA_RAIL=0xa813cb1BF558245a1287b69b4bE6e4E43F8074F7
OPEN=1
DESK=0x4987b70136c5C4071900C6404b3b47C34142a234
SETTLE=settleRemittance(address,uint256)
FEE_BPS=200
FEE_TO=HOT
```
