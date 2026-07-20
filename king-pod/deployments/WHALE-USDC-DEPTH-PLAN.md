# Whale gameplan — shift to live USDC depth

**Shift:** Stop expecting spendable USDC from the empty sovereign RSS/USDC Morpho market. Route Kingdom borrow demand to **active Base pools** where capital already flows.

## Plan (plain English)

**1. Scout (Morpho app / explorer)**  
Filter Base → Loan asset **USDC**. Rank by **idle = Total Supply − Total Borrowed**. Ignore thin custom books. Prefer markets with idle **>> ops need** (millions+, not dollars).

**2. Target curator rails (whale water)**  
Prioritize markets fed by **Steakhouse / Gauntlet / Re7** USDC vaults on Base (hundreds of millions supplied into blue-chip books — cbBTC, WETH, wstETH, etc.). That idle is real cash depth ready to borrow against **accepted collateral**.

**3. Match collateral to the pool**  
Whale USDC sits behind **their** collateral list. RSS may not be listable there. Either: post collateral those markets accept, or bridge/route value into accepted form — then borrow USDC out to cold Landing. Sovereign RSS market stays for RSS rails; **ops funding** uses deep USDC venues.

**4. Execute ladder**  
Pick one deep market → micro live borrow → USDC on Landing → confirm Basescan → scale ($500k tests, then larger). Keep Vault V2 deallocate path for Kingdom vault positions; don’t conflate it with whale-pool borrows.

**5. Done looks like**  
Kingdom ops funded from **live idle USDC**, not an empty self-book. Two tracks: sovereign RSS rails + whale USDC borrow venues.
