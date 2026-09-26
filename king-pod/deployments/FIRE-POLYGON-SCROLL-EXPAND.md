# FIRE — Polygon expansion + Scroll ZK path

**Mode:** FIRE · Polygon executed · Scroll armed (await L2 ETH spark)  
**Passport:** vault `0x31511861a519D6b814Eb20b4A0bcc391e76177dF` · seeded with **~12.925 POL**  
**POL remaining after fire:** ~**8.80 POL**

---

## Polygon (chain 137) — LIVE

| Module | Address |
|--|--|
| **CrownKingAgent** | `0x18a3cAd4b67F9Ee487743ce5C7943C0A57E012E1` |
| CrownSovereignEusd | `0xd8A639BbD49e02eA590569D548d578e8345baf50` |
| CrownSpendVault | `0x8dCbFcA6dB84C33A73c0daef7cf19Ed1C3B6d91b` |
| CrownLsrEusd | `0x04fC02fE9F40A49c5afa00a8f0B2cdbE55da3b1E` |
| CrownNavMirror | `0x480bcB03Ce3077112Cdcf0Ba5BDC589470986215` |
| CrownZkAttest | `0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211` |
| CrownColdBuffer | `0xc498c211CA17EE19C852Daa7E4e75af347f3FB0d` |
| CrownPayAdapter | `0x2FAEd8D83f61d157419b33F7938aDCd9F2c4f629` |
| **CrownOpenMoney** | `0xe3e165C8823d35966C85353D5A4f257623417a7c` |
| CrownAllowlist | `0x02d4A11311536a0E1Da652640bc4E2b280E8cb17` |
| CrownRailShield | `0xd1FaCE3C48A050bC08BB18AB12951a72aBC5Efe3` |

### Verified
- `bordersSecure() = true` · epoch **1**
- Smoke **payroll 1,000,000 eUSD** minted to vault
- Open Money first invoice created (`FIRST-GLOBAL-INVOICE`)
- Cold funded with vault USDC dust (~$0.49)
- 39/39 receipts success

Broadcast: `broadcast/FirePolygonExpand.s.sol/137/run-latest.json`

---

## Scroll (privacy) — LIVE

Fired from Scroll hot `0xca76AE9e29a5F01465D890dc30109cD58B78F864`.

| Module | Address |
|--|--|
| **CrownNavMirror** | `0x9cdF3B5811637885346237fd30416a7bECC750af` |
| **CrownZkAttest** | `0x2ab17e3c00D783F58B106De2fB1723b4915Da257` |
| **CrownRailShield** | `0x57326e4001F00adFd48Be6976653A694F64d26d0` |

### Verified
- `bordersSecure() = true` · epoch **1**
- NavMirror `totalAssets` = **$228.9M** (Base yRSS mirror)
- Broadcast: `broadcast/FireScrollAttest.s.sol/534352/run-latest.json`

---

## Kingdom triangle

```
Base (speed / gold rail yRSS) ✓
Polygon (liquidity / Open Money / agent) ✓
Scroll (privacy ZK attest) ✓
```

---

## Key hygiene

One-time Polygon passport key used for this fire only — **do not commit**. Rotate after ops if exposed in chat.
