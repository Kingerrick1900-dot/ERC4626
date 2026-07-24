# Kingdom Armed — Live Levers

**No broadcast without King `KING_GO=1` + named fire flag.**

Idle check is instantaneous: if ELE idle **> 0**, fire borrow. If idle **= 0**, run `NEXT-PLAN.md` (surface + open doors) — never park on “when idle.”

## Live power

| Engine | Live | Armed |
|--|--|--|
| Morpho ELE | 40.1M Elepan coll · ~$14M borrow · ~$16.9M room | `FIRE_MORPHO_PULL` → **~20.1M Elepan** free @ 70% LTV |
| CDP | 25.2M Elepan · 13M eUSD · HF 1.94 | `FIRE_CDP` → **~5.05M Elepan** + **~3.26M eUSD** → Landing |
| yELEPAN-USDC | ~$14M · #7 Base Morpho USDC vault | shares on Landing |
| ZK Gate | proven **$1M** | supply → draw → Landing |
| Free Elepan (hot) | **~34.58M** | liquid |

Fork-proven: Morpho pull 20M+ · CDP max withdraw · CDP max mintTo Landing.

---

## Fire

### Morpho — free ~20M Elepan (borrow stays)
```bash
cd king-pod
KING_GO=1 FIRE_MORPHO_PULL=1 \
  forge script script/FireMorphoPullElepan.s.sol:FireMorphoPullElepan \
  --rpc-url $BASE_RPC --broadcast --slow
```

### CDP — withdraw Elepan + mint eUSD
```bash
KING_GO=1 FIRE_CDP=1 MODE=both \
  forge script script/FireCdpSurface.s.sol:FireCdpSurface \
  --rpc-url $BASE_RPC --broadcast --slow
```

### Morpho borrow → Landing
```bash
# only if idle > 0 at send time — script enforces IDLE_FLOOR
KING_GO=1 FIRE_BORROW=1 BORROW_USDC=<raw6> \
  forge script script/FireElepanBorrowUsdc.s.sol:FireElepanBorrowUsdc \
  --rpc-url $BASE_RPC --broadcast --slow
```

Plan: `NEXT-PLAN.md`
