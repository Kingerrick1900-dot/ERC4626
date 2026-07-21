# ZK Advance Test — Status after KING GO

**KING GO received. Fire attempted.**

| Check | Result |
|-------|--------|
| ZK `isProven` | **true** |
| kUSD stock | **699,994** |
| Advance amt | **\$500,000** |
| Buyer wallet | hot `0x6708…a7d1` (no BUYER_KEY set) |
| Buyer USDC | **\$1.04** |
| Broadcast | **BLOCKED — BUYER_USDC_SHORT** |
| Tx hash | **none** (preflight revert, no on-chain fail) |

Shield armed. Door armed. Calldata ready.  
**Missing:** real buyer with ≥ \$500k USDC — set `BUYER_KEY` (counterparty or King-controlled funded wallet) and re-GO.

```bash
KING_OK=1 KING_GO=1 FIRE_ZK_TEST=1 ADVANCE_USDC=500000000000 BUYER_KEY=<funded> \
  forge script script/FireZkAdvanceTest.s.sol:FireZkAdvanceTest --rpc-url $BASE_RPC --broadcast
```
