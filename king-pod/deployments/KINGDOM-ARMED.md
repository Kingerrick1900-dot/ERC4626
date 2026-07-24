# Kingdom Armed — Live Levers

**No broadcast without King `KING_GO=1` + named fire flag.**

## Live power

| Engine | Live | Armed pull |
|--|--|--|
| Morpho ELE | 40.1M Elepan coll · ~$14M borrow open | **~20.1M Elepan** free to hot @ 70% LTV |
| CDP | 25.2M Elepan · 13M eUSD · HF 1.94 | **~5.05M Elepan** withdraw + **~3.26M eUSD** mint → Landing |
| yELEPAN-USDC | ~$14M · #7 USDC vault on Base Morpho | shares on Landing |
| ZK Gate | proven **$1M** | credit rail live · draw to Landing |
| Free Elepan (hot) | **~34.58M** | already liquid |

Fork-proven clean: Morpho pull 20M+ · CDP max withdraw · CDP max mintTo Landing.

---

## Fire

### 1) Morpho — free ~20M Elepan (borrow stays)
```bash
cd king-pod
KING_GO=1 FIRE_MORPHO_PULL=1 \
  forge script script/FireMorphoPullElepan.s.sol:FireMorphoPullElepan \
  --rpc-url $BASE_RPC_URL --broadcast --slow
# optional: PULL_ELEPAN=<raw8dp>
```

### 2) CDP — withdraw Elepan + mint eUSD
```bash
KING_GO=1 FIRE_CDP=1 MODE=both \
  forge script script/FireCdpSurface.s.sol:FireCdpSurface \
  --rpc-url $BASE_RPC_URL --broadcast --slow
# MODE=withdraw | mint | both
# optional: WITHDRAW_ELEPAN / MINT_EUSD
```

### 3) Morpho borrow → Landing (when market idle is live)
```bash
KING_GO=1 FIRE_BORROW=1 BORROW_USDC=<raw6> \
  forge script script/FireElepanBorrowUsdc.s.sol:FireElepanBorrowUsdc \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

---

## One-line

> Pull the Elepan. Mint the eUSD. Borrow when idle hits. King GO only.
