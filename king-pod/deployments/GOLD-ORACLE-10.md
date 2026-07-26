# Kingdom Gold — Morpho credit surface @ $10

Institutional collateral lane on Base: **kXAU / USDC** on Morpho Blue, AdaptiveCurve IRM, **91.5% LLTV**, fixed kingdom oracle at **$10** per full kXAU unit (8 decimals → Morpho `price()` = `1e35`).

## Design

| Piece | Spec |
|--|--|
| Collateral | `CrownGold` (**kXAU**) — kingdom gold receipt, 8dp |
| Loan | USDC (`0x833589fC…`) |
| Oracle | `CrownFixedOracle` @ **$10** (`1e35`) |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | 91.5% |
| Min seed | **$1 USDC** matched self-seed (supply ≈ borrow) |

kXAU is a sovereign receipt unit for Morpho collateralization — not a PAXG/XAUt wrap. Spot XAU reference on Base (Chainlink) remains available for later oracle upgrade; this book opens on the **$10** kingdom quote.

## Fire

```bash
KING_GO=1 FIRE_GOLD_ORACLE_TEN=1 \
forge script script/FireGoldOracleTen.s.sol:FireGoldOracleTen \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Optional: `SEED_USDC=1000000` (default $1) · `GOLD_MINT=100000000` (default 1.0 kXAU).

## Fork

```bash
forge test --match-contract GoldOracleTenForkTest -vv
```

## Physics

Matched self-seed: flash USDC → supply market → borrow vs kXAU @ $10 / 91.5% → repay flash. Hot wallet Δ USDC ≈ 0. King holds collateral + supply shares + debt. Pool is live at minimum size for subsequent scale.

## Live (Base) — fired

| Piece | Address / value |
|--|--|
| kXAU | `0x76822B470DeC1b94Df4219727288e7a196224853` |
| Oracle ($10 / `1e35`) | `0xCf2BC42FC9d158CCd77462c24670F17Cc57dBEd0` |
| Helper | `0xB16E55aa18155715652e6F4F15654e600B0988aC` |
| Market id | `0xe433538a1eafb9ae985f6962435f6b14a1e27d50f8f30cab99b517f68b5e23da` |
| Supply / borrow | **$1 / $1** (matched) |
| King coll | **1.0 kXAU** |

Create tx: `0xa0b0907b7825f0d441941d927b7dfa8561f85712aa956352e515fe2475a349ad`  
Oracle tx: `0xec17f2747969f49e378805408398f52a4ec7314268f68fc0a20a731331d1f116`
