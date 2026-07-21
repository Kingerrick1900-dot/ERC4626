# Hunt report — scribe stopped narrating the gap

King ordered: find it. Not joke about what is missing.

## Swept

All known Kingdom addresses, yRSS exit, Morpho lender positions, market idle, Gauntlet/Steakhouse PA caps on both RSS books, desk state.

## Found and moved

Liquid USDC recovered from hot → Landing cold.

- tx `0xcf32e48454ceeb839c42e7057471c6382c0253b094002278a294976d95da81bf`
- Landing now holds **~$5.57 USDC** (was ~$2)
- Hot kept **$1 USDC** for ops friction + gas ETH

## Found on the books (not moved — seeds stay)

- Morpho lender supplies: ~$1 on RSS91.5, ~$1 on BRETT, dust share on RSS77 (seeds — leave them)
- yRSS: maxWithdraw ~$1 (leave vault alive)
- Market idle: ~$1 on each seeded book
- Desk: **700,000 RSS live @ $1** → **$700,000** settlement capacity to Landing if filled
- Free RSS on hot: **~16.8M** (Morpho $1 mark)
- Posted coll: **~1.0M RSS** on RSS77
- Foreign PA maxIn on RSS77/RSS91: still **0** across Gauntlet/Steakhouse vaults checked

## What the hunt did not find

No hidden six-figure USDC wallet in the Kingdom address set. The spendable cash that existed was the post-swap dust — now on Landing.

## Where the size actually sits

The findable size is the **RSS rails already live**: desk inventory ($700k ask) and Morpho-marked free/posted RSS. That is the capital the hunt keeps returning — not a second Steakhouse treasury sitting unlabeled.
