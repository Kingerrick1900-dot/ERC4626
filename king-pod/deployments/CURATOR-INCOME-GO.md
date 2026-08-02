# Curator Income + ZK Completer — King Go

## Live arm (yELE)

| Knob | Target |
|--|--|
| Vault | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Curator / owner | hot |
| Performance fee | **10%** of interest (`0.1e18`) |
| Fee recipient | **hot** (ops) |
| ELE77 cap | enabled · $14M |
| TEN `$10` cap | **submitted** → `acceptCap` after timelock (~2d) |
| PA maxIn ELE77 / TEN | **$700k** each |
| WETH cap | pending until `validAt` — then `acceptCap` |

```bash
KING_GO=1 FIRE_YELE_INCOME=1 \
forge script script/FireYeleCuratorIncome.s.sol:FireYeleCuratorIncome \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

After timelock on TEN:

```bash
# acceptCap TEN market params (oracle $10 / 91.5%) — separate fire when ready
```

## Vault product (deposit sink)

yELE = Kingdom USDC vault under King curation.  
Depositors supply **USDC** → allocator routes to ELE/USDC (and TEN/$10 when live).  
Curator fee skims interest to hot. This is the income layer when TVL is real.

## ZK completer — activate $700k draw

| Piece | Address |
|--|--|
| Completer | `0x12514e1f999131eA78D402a7258b67A65F9342Ff` |
| Credit | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| maxAsk | **$700,000** |

Matcher (USDC holder):

```bash
# ask ≤ 700000e6
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" \
  0x12514e1f999131eA78D402a7258b67A65F9342Ff \
  700000000000 \
  --rpc-url "$RPC_URL" --private-key "$MATCHER_KEY"

KING_GO=1 FIRE_LOAN_MATCH=1 ASK_USDC=700000000000 MATCHER_KEY=... \
forge script script/FireMatcherComplete.s.sol:FireMatcherComplete \
  --rpc-url "$RPC_URL" --broadcast --slow
```

Flow: `complete(ask)` → `credit.supply` → `operatorBorrowTo(Landing)`.

## Order of money

1. Outside USDC → yELE (curator fee income) **and/or**  
2. Outside USDC → completer `complete` → Landing (ops draw)  
3. After TEN `acceptCap`: vault can allocate into $10 oracle market under King price rail
