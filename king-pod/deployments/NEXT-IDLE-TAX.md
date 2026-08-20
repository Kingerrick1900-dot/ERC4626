# NEXT — Idle door + Merkl amp (post-GO)

Peapods scream **LIVE**. 100M eUSD **LIVE**. Morpho $200M signal **intact**.  
Landing USDC still ~$2.41 — need **real idle** for tax extract.

## Live blockers (with fixes)

| Block | Fix |
|--|--|
| yRSS RSS/$1200 **disabled** | **ArmYrss1200** — we own curator. Opens cap + PA $700k flow |
| Merkl ELE `minAmount=0` | Whitelist ELE **or** fund **USDC** rewards (USDC is whitelisted, min $0.90) |
| Hot USDC ~$0.10 | Fund Merkl budget on hot (e.g. $50k) before `FIRE_MERKL=1` |
| Market idle ~$0 (matched) | Merkl/PA/unmatched supply — then `BorrowIdleToLanding` |

## Fire order

### A — Arm the door (no Merkl money needed)

```bash
KING_OK=1 forge script script/ArmYrss1200.s.sol:ArmYrss1200 \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

Enables RSS/$1200 on yRSS, PA maxIn/Out $700k.

### B — Merkl FIXED_RATE (follow-up amp)

```bash
# 1) Fund hot with USDC budget (e.g. 50_000e6)
# 2) Encode
./script/merkl/encode_rss1200_fixed.sh 7200 50000000000
source script/merkl/rss1200-fire.env

# 3) Fire
KING_OK=1 FIRE_MERKL=1 forge script script/FireMerklRss1200Fixed.s.sol:FireMerklRss1200Fixed \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

Studio backup: Morpho → Market `0x41c080…` → Supply → **FIXED_RATE** → paste `CAMPAIGN_DATA`.

### C — Tax extract (when idle ≥ $700k)

```bash
KING_OK=1 forge script script/BorrowIdleToLanding.s.sol:BorrowIdleToLanding \
  --rpc-url https://mainnet.base.org --broadcast -vvv
```

Optional PA pull if Steakhouse opens maxIn: `PaSeedRss1200`.

## Agent

Needs hot `PRIVATE_KEY` for A (and B/C when funded). Paste one-time → arm door first.
