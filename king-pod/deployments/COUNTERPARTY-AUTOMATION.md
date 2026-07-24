# Counterparty Automation — Multi-Rail (Mission)

**Not one option.** Fill can arrive on any rail. Draw is automated.

---

## Rails (all live)

### A — ZK Credit (permissionless)
Anyone supplies USDC → credit `0xc415…d936` → auto-draw pokes Landing.

| Field | Value |
|--|--|
| Supply | `supply(uint256)` — open |
| Ask | $500,000 raw `500000000000` |
| Calldata | `0x35403023000000000000000000000000000000000000000000000000000000746a528800` |
| Approve USDC spender | credit address |
| Draw | `CrownZkAutoDraw.poke()` or `FIRE_ZK_CREDIT` |

### B — Morpho PA curators (ELE market `0xa4ec5271…`)
Capital already on Base. Counterparties = vault curators setting `maxIn`:

| Vault | TVL class | Address |
|--|--|--|
| Gauntlet USDC Prime | ~$428M | `0xeE8F…b61` |
| Steakhouse Prime USDC | ~$229M | `0xBEEF…b2` |
| Steakhouse USDC | ~$183M | `0xbeeF…183` |
| Moonwell Flagship USDC | ~$9M | `0xc125…A2Ca` |
| Spark USDC | ~$6.7M | `0x7BfA…34A` |
| Yearn OG USDC | ~$2.0M | `0xef41…D03` |
| Gauntlet USDC Core | ~$1.9M | `0xc0c5…Db12` |

Packet: `CURATOR-PACKET-ELE-USDC.md`  
On first `maxIn > 0` → `FIRE_BORROW` same block.

### C — ELE market idle
If idle > 0 → `FIRE_BORROW` (script-enforced). No deferred lane.

### E — Institutional balance-sheet (Ledn / Galaxy)
Pledge bankable BTC/ETH to lender custody — cash does not need ELE Morpho idle.  
Sheet: `INSTITUTIONAL-CASH-LANE.md` · packet ready for desk.

| Lender | Min | Collateral |
|--|--|--|
| Ledn | ~$1k BTC coll · $500 loan | **BTC** |
| Galaxy GOFR | **$1M** loan | BTC / ETH / desk-structured |

---

## Automation pieces

| Piece | Role |
|--|--|
| `FindCounterparties.s.sol` | Fanout readiness every rail |
| `FireZkCreditDraw.s.sol` | King-sized draw |
| `CrownZkAutoDraw` | Permissionless poke on fill — **LIVE** `0xB6481E2ca95c14BC47B29b60fec6eF7e4A398a23` (operator set) |
| `FireDeployZkAutoDraw.s.sol` | Deploy keeper |
| `FireElepanBorrowUsdc.s.sol` | Morpho draw on idle |

```bash
forge script script/FindCounterparties.s.sol:FindCounterparties --rpc-url $BASE_RPC
KING_GO=1 FIRE_ZK_AUTO=1 forge script script/FireDeployZkAutoDraw.s.sol:FireDeployZkAutoDraw --rpc-url $BASE_RPC --broadcast --slow
```

---

## Completion rule

Supply hits **any** rail → USDC on Landing. Keeper / fire scripts finish the path. Mission = rails armed + fanout live + auto-draw deployed.
