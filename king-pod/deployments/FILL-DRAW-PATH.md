# FILL → DRAW — inventory path

**Law:** Cash into credit first, then draw to Landing. No flash.

## Live targets (Base)

| Piece | Address |
|-------|---------|
| Credit | `0x5568fE662363d7F3fa52349A99C9e19C6616B60d` |
| Router | `0xBb3C372D4A0C398b6107f13ea4b1AB00B2b0A7aC` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

## Status (checked)

| Check | Result |
|-------|--------|
| Arbitrum HOT USDC | **$0** |
| Arbitrum HOT ETH | **$0** |
| Base HOT USDC | ~**$1** |
| Credit idle | **$0** |
| Capacity | **$11M** |

Chain is empty, not blocked. Bridge/wire **$1M USDC to Base HOT**, then:

```bash
AMT=1000000000000 PRIVATE_KEY=0x… \
  bash king-pod/script/FireFillCreditDrawCast.sh
```

That: approve → `credit.supply` → arm → `router.draw` → Landing.

Debt then equals spendable Landing USDC. King's law held.
