# King Pod (Option A)

Self-lending liquidity bootstrap on Base. Spec: [`SPEC.md`](./SPEC.md).

## Crown locks

- Signer: `0x6708…`
- RSS price (oracle): **$0.05**
- Liquid reserve: **21M RSS**
- Bootstrap RSS: **20.979B**
- LLTV: **70%**
- Core team cut: **12% of free USDC after Phase A** — not from flashloan

## Phase A truth

Bootstrap leaves **LP + debt**, free USDC **≈ 0**. The “$3.5M borrow → 12% team / cbBTC / Aave / PAXG” allocation is **Phase C** and requires **external USDC** (or a later solvent surplus). Scribe will not ship math that flashloans $5M and repays with a $3.5M borrow.

## Test

```bash
forge test -vv
```

## Deploy (Base)

```bash
export BASE_RPC=...
export PRIVATE_KEY=...   # 0x6708… must hold Base ETH for gas
forge script script/Deploy.s.sol:Deploy --rpc-url $BASE_RPC --broadcast --private-key $PRIVATE_KEY
```

Then approve RSS → Pod and call `bootstrap(20979000000000000000000000000, 5000000000000)`.
