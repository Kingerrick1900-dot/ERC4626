# Elepan Protocol Specs

**Chains:** Base `8453` · Scroll `534352`  
**Posture:** Independent sovereign credit. Base holds inventory; Scroll is Elepan-native ruleset. Morpho is an optional foreign venue on Base only.

---

## Empire abstract — LIVE (~100 words)

Elepan is dual-domain sovereign credit under King Errick. On Base — hot curator, Landing as liquid sink: ~98M ELE free, ~2M ELE Morpho collateral, ~$700k USDC lit in yELE via one real ELE flash-seed; Uni sale sources for ELE/GOLD; DiskFill and WETH acceptCap ready as optional Morpho rails. On Scroll — Gold CDP locks 100,001 kXAU against ~645k eUSD; ~545k eUSD cold (`0xD42A…`), 100k eUSD convert tranche on hot; dominion gate, credit, and completer live to Landing; Uni rails for kXAU/eUSD/USDC. Domains parallel. Morpho Base-only and optional. Attestation ZK-ready. Gold highlight intact. Kingdom book seeded.

### External liquidity — Morpho venue (~100 words)

External liquidity on Base routes through kingdom MetaMorpho. **yELE accepts USDC only** — ELE cannot deposit. One real ELE flash-seed lit **~$700k** into yELE against ~2M ELE Morpho collateral (matched supply/borrow). After WETH market `acceptCap`, DiskFill can settle USDC from hot through yELE → Morpho → **Landing** when a real USDC ask exists. Flash-seed lights the book; it is not Landing payroll. Morpho remains an optional venue; **Landing** remains the liquid destination.

---

## 0) Thesis

Elepan is a dual-domain credit stack. **ELE** is the monetary base. **eUSD** is the kingdom stable. **kXAU** is hard gold collateral that prices capacity and mint. **yELE / yRSS** are USDC MetaMorpho vaults that route liquidity into kingdom Morpho markets. Attestation (today owner-attested; Groth16-ready) sets borrow capacity. Completers cold-or-revert USDC to Landing. No self-lend mirror as payroll. No Morpho on Scroll.

---

## 1) Wallets

| Role | Address | Domain |
|--|--|--|
| Hot / King (Base) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` | Curator, CDP owner, Morpho ops |
| Landing (Base) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` | Liquid destination; Vault V2 owner; CDP fee recipient |
| Scroll Hot / King | `0xca76AE9e29a5F01465D890dc30109cD58B78F864` | Scroll dominion owner |
| Scroll Landing | `0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f` | Completer / Gold CDP mint destination |
| Loop (ops) | `0x8d3cfbFc6A276f118579517E4d166e94C66F8585` | Carry/scaler signer |

---

## 2) Tokens

### 2.1 Base

| Asset | Address | Dec | Role |
|--|--|--|--|
| **ELE** (`elephanToken`; on-chain symbol `RSS`) | `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` | 8 | Sovereign monetary base; TEN / ELE77 / CDP collateral |
| **RSS** (PoD unit) | `0x7a305D07B537359cf468eAea9bb176E5308bC337` | 18 | Morpho RSS/USDC PoD collateral (distinct from ELE) |
| **eUSD** (live rail) | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` | 18 | Kingdom USD; minter = Base CDP; owner = Hot |
| **kXAU** (GOLD) | `0x76822B470DeC1b94Df4219727288e7a196224853` | 8 | Gold receipt; GOLD91 / GOLD77 collateral |
| **USDC** | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | 6 | Loan / vault asset |
| BRETT | `0x532f27101965dd16442E59d40670FaF5eBB142E4` | 18 | Oracle-moat Morpho collateral |
| WETH | `0x4200000000000000000000000000000000000006` | 18 | Idle-source market |
| cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | 8 | Idle-source market |
| cbETH | `0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22` | 18 | Carry path (ops-gated) |

**Naming rule:** ELE (`0x50639…`, 8dp) ≠ RSS PoD (`0x7a305…`, 18dp). Specs must never conflate them.

### 2.2 Scroll

| Asset | Address | Dec | Role |
|--|--|--|--|
| **eUSD** | `0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B` | 18 | Dominion stable; minted to Landing |
| **kXAU** | `0x156d912F37C179798D8396Da5d58919FA634262d` | 8 | Gold receipt powering gate + Gold CDP |
| **USDC** | `0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4` | 6 | Credit pool asset |

### 2.3 Oracles (Base)

| Oracle | Address | Scale | Use |
|--|--|--|--|
| RSS Fixed $1 | `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` | `1e24` | RSS77 (owner burned) |
| ELE Fixed $1 | `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` | `1e34` | CDP + ELE77 |
| TEN Fixed $10 | `0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385` | `1e35` | TEN (ELE @ $10) |
| GOLD Fixed $10 | `0xCf2BC42FC9d158CCd77462c24670F17Cc57dBEd0` | `1e35` | GOLD91 / GOLD77 |
| BRETT UniV3 TWAP | `0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619` | TWAP | BRETT market |
| Chainlink XAU ref | `0x69f29e7ce307df6f8412b115b242ec2791f5c40e` | live feed | Reference surface |

### 2.4 Oracles (Scroll)

| Oracle | Address | Scale | Use |
|--|--|--|--|
| GOLD Fixed $10 | `0xccB83516c5E9c557B9407ABF00865fe516B4a8c8` | `1e35` | Gold CDP + attest sync |

---

## 3) Stablecoins & rails

### 3.1 eUSD (Base)

| Field | Spec |
|--|--|
| Contract | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Issuer | Base CDP only (minter) |
| Peg surface | Soft peg via PSM ↔ USDC; Morpho/Uni venues optional |
| Owner | Hot |
| Wrong surface | `0xaeDcB6cCEc9739A3a2e4c4d3F914BC676a906E55` — **do not use** |

### 3.2 PSM (Base)

| Field | Spec |
|--|--|
| Contract | `0x9199E5099C2C46A688F982E377a146Ab6db8060b` |
| Pair | eUSD ↔ USDC |
| feeBps | `0` |
| Paused | false |
| Owner | Hot |
| Role | Clear eUSD → USDC after CDP mint |

### 3.3 eUSD (Scroll)

| Field | Spec |
|--|--|
| Contract | `0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B` |
| Issuer | Scroll Gold CDP |
| Destination | Scroll Landing (cold-or-revert) |
| Live mint | ~**645,167.74** eUSD against **100,001** kXAU @ 155% safety |

### 3.4 Doctrine — stables

1. **eUSD is kingdom liability**, not a Morpho share token.  
2. Base eUSD clears through PSM; Scroll eUSD settles to Landing.  
3. USDC is the foreign clearing asset for credit pools and MetaMorpho vaults.  
4. Gold (kXAU @ $10) is the highlight collateral — capacity and mint both derive from it on Scroll.

---

## 4) CDP / credit engines

### 4.1 Base CDP

| Field | Spec |
|--|--|
| CDP | `0x46b1D159b3a2694e7b70F550b7d5dEf6df451174` |
| Collateral | ELE (8dp) |
| Debt asset | eUSD (18dp) |
| Oracle | ELE Fixed $1 |
| Safety | **155%** |
| Fee recipient | Base Landing |
| Owner | Hot |
| Path | deposit ELE → mint eUSD → PSM/venue → repay → withdraw |

### 4.2 Scroll sovereign credit

| Piece | Address | Params |
|--|--|--|
| Gate (`CrownSovereignGate`) | `0x777CCe01CbF472070b6c66dB2295b2d616171887` | minThreshold **$700k**; proofTtl **30d**; gold-synced threshold **$1,000,010** |
| Credit (`CrownZkCredit`) | `0x5c2511748a398AA7Fe144B44e0a433F5156A1368` | LLTV **70%**; public USDC supply; cold borrow to Landing |
| Completer (`CrownZkLoanComplete`) | `0x2cf08F8150f7E89c7323615016b0c4D2811266f6` | maxAsk = threshold × 70% → **$700,007** post gold |
| Spoils | `0x8E5ff2552f8fE0730E89dA7fBF1721f910615DcD` | Capacity / claim surface |
| Gold CDP | `0x6876E987F8C9d9e661068C610D9290Df41D4889f` | SAFETY **155%**; mint → Landing; King-only |
| Gold attest sync | `0x89c38F150Ae4875799fDB1332C66aD9169cA0fdF` | capacity = (free kXAU + CDP coll) × $10 |

**Flow:**  
`kXAU → oracle $10 → gate attestation → completer maxAsk`  
`kXAU → Gold CDP → eUSD → Landing`  
`USDC lenders → credit.supply → completer.complete → Landing`

Initial dominion attestation (pre-gold): capacity **$1B**, maxAsk **$700M**. Gold sync retunes capacity to gold mark.

### 4.3 ZK surface

| Item | Spec |
|--|--|
| Gate ABI | `isProven(subject)` / `attestations(subject)` / `minThreshold` |
| Today | Owner attestation (sovereign) |
| Upgrade | Swap for Groth16 (`wallet_reserves` circuit, bn128) without changing credit ABI |
| Artifacts | `king-pod/zk/build/` — zkey, vkey, verifier sources |
| Base ZK ops | Compiled historical surfaces; **Scroll gate is the live attested path** |

---

## 5) Vaults — yELE & yRSS

IRM (all Morpho markets): AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687`  
Morpho Blue: `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`

### 5.1 yELE / yELEPAN-USDC

| Field | Spec |
|--|--|
| Address | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Name / symbol | King Elepan USDC Vault / **`yELEPAN-USDC`** |
| Asset | USDC |
| Owner / Curator | Hot |
| Fee | **10%** (`1e17`) |
| Fee recipient | Hot |
| Timelock | **172800** (2 days) |
| Guardian | `0x0` |
| Allocators | Hot + Public Allocator |
| Supply queue[0] | **ELE77** — enabled, cap **$14,000,000** |
| Pending caps | GOLD91, GOLD77, TEN — each **$14,000,000** (accept after `validAt`) |
| WETH idle | **LIVE** — cap **$50,000,000** enabled `2026-07-27` · tx `0x873cc2e45b4b32db14e1a82eef1fe30be364317051983abcca72767bcbf5d6a8` |

**Role:** Curated USDC vault concentrating liquidity into Elepan Morpho markets (ELE @ $1 / $10, GOLD @ $10). Income fee accrues to Hot.

### 5.2 yRSS / yRSS-USDC

| Field | Spec |
|--|--|
| Address | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Name / symbol | King RSS USDC Vault / **`yRSS-USDC`** |
| Asset | USDC |
| Owner / Curator | Hot |
| Fee | **10%** |
| Fee recipient | Base Landing |
| Guardian | `0x0` |
| Timelock | 0 (sheet) |
| Public Allocator | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| Caps | RSS **$14M**; BRETT **$2M**; PA maxIn/Out ~**$700k** |
| Queue | cbBTC, WETH, RSS77, BRETT |

**Role:** Historic PoD / idle-source vault. Books cleared on RSS Morpho self-seed; recycle gated by exit doctrine.

### 5.3 Vault V2

| Field | Spec |
|--|--|
| VaultV2 | `0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9` |
| Adapter | `0x3088de5b1629C518382a55e307b1bD45f3BFEE8c` |
| Owner | Base Landing |
| Curator | Hot |
| Allocators | Hot + Landing |
| Market | RSS77 |
| `forceDeallocate` penalty | **1%** |
| Seed | ~$1 dead shares |

### 5.4 Retired

| Piece | Address | Status |
|--|--|--|
| KingVault / Cake | `0xA1aFcb46a64C9173519180458C1cF302179c832a` | **RETIRED** — do not route |

---

## 6) Morpho markets (Base only)

| Alias | Market ID | Loan / Coll / Oracle / LLTV | Notes |
|--|--|--|--|
| **RSS77** | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` | USDC / RSS / $1 / **77%** | Historic $9.25M self-seed; books cleared / freed |
| **BRETT** | `0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16` | USDC / BRETT / TWAP / **62.5%** | Kingdom-created moat; yRSS cap $2M |
| **TEN** | `0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc` | USDC / ELE / $10 / **91.5%** | Unwound; ELE returned toward hot |
| **ELE77** | `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc` | USDC / ELE / $1 / **77%** | yELE queue[0]; **$14M** cap enabled |
| **GOLD91** | `0xe433538a1eafb9ae985f6962435f6b14a1e27d50f8f30cab99b517f68b5e23da` | USDC / kXAU / $10 / **91.5%** | Lit (~$1 USDC seed); pending yELE $14M cap |
| **GOLD77** | `0x339d9b5aca7606998f646723f3f978fa1213ecc9ff60d0a02f2f92ecac4e8d4b` | USDC / kXAU / $10 / **77%** | Empty; pending yELE $14M cap |
| cbBTC/USDC | `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836` | foreign idle | yRSS source |
| WETH/USDC | `0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda` | foreign idle | yRSS source |

**Helpers:**  
`CrownSelfSeedGold` `0xB16E55aa18155715652e6F4F15654e600B0988aC` · `CrownUnwindBook` `0x21dA98ba831d02Da5F7E47FE83A67091883942dD`

---

## 7) Domain doctrine

| Domain | Law |
|--|--|
| **Base** | Hold ELE / kXAU / RSS inventory. Morpho = optional overcollateralized venue. ZK attestation ≠ Morpho collateral. |
| **Scroll** | Elepan **is** the ruleset. Gate → credit → completer → Landing. Gold CDP → eUSD. **No Morpho.** |
| **Independence** | Domains parallel. Base ELE inventory must not move for Scroll deploys. Sovereign clear = zero Base CDP debt. |
| **Gold** | Highlight rail. $10 kingdom oracle. Caps submitted on yELE ($14M GOLD91/77). |
| **Liquidity** | Seed pools with real USDC. Completer and gold CDP settle to Landing. |
| **Flash** | Only with named same-tx `REPAY_SOURCE` (`FLASH-POLICY.md`). |
| **Recycle** | Freed assets stay liquid until fork-tested exit + King green light (`NO-RECYCLE-UNTIL-EXIT.md`). |
| **Ops freeze** | MIN_ETH≥0.05, MIN_BORROW≥$50, gas tax&lt;5%, edge≥200bps; `CARRY_ARMED=1` (`OPS-FREEZE.md`). |

---

## 8) Economic parameters (canonical)

| Param | Value |
|--|--|
| CDP / Gold CDP safety | **155%** |
| Scroll credit LLTV | **70%** |
| ELE77 / RSS77 LLTV | **77%** |
| TEN / GOLD91 LLTV | **91.5%** |
| BRETT LLTV | **62.5%** |
| GOLD / TEN oracle | **$10** |
| ELE / RSS Fixed oracles | **$1** |
| yELE / yRSS performance fee | **10%** |
| yELE timelock | **2 days** |
| yELE ELE77 / pending gold / TEN caps | **$14,000,000** each |
| Vault V2 forceDeallocate | **1%** |
| Gate proof TTL | **30 days** |
| Gate minThreshold | **$700,000** |

---

## 9) System diagram

```
BASE                              SCROLL
────                              ──────
ELE (hold)                        Gate (attest / gold sync)
kXAU (hold + Morpho coll)         Credit (USDC supply @ 70% LLTV)
Base CDP → eUSD → PSM             Completer → Landing USDC
yELE → ELE77 / GOLD* / TEN        Gold CDP → eUSD → Landing
yRSS → RSS77 / BRETT / idle       Spoils dominion
Morpho Blue (optional venue)      (no Morpho)
```

---

## 10) Sale-source Uniswap V3 (desk plumbing)

Same-chain exit surfaces so inventory can clear to USDC. Desk liquidity — not protocol law.

### Base

| Pair | Fee | Pool | NFT | Seed |
|--|--|--|--|--|
| ELE / USDC | 0.3% | `0x4615a3E473944C12bDF4e1E3d1ea5e5968397410` | `5669978` | 1 ELE + $1 |
| GOLD / USDC | 0.3% | `0x47EBd710De9c0396AC44927A7CC3345F13b321A7` | `5669999` | 0.1 GOLD + $1 |

Doc: `ELE-GOLD-SALES-SOURCE-LIVE.md`

### Scroll

| Pair | Fee | Pool | NFT | Seed |
|--|--|--|--|--|
| kXAU / USDC | 0.3% | `0xce5Dd7bF3acd10152a601563AE2730b3E4dCD241` | `11056` | 0.02 kXAU + $0.20 |
| eUSD / USDC | 0.3% | `0x5f3f22344FbBF23DD6cF63670B05d4C6689063Fc` | `11057` | 0.2 eUSD + $0.20 |
| kXAU / eUSD | 0.3% | `0x9c5768f292A85080294C7764b54930F3C560788d` | `11058` | 0.05 kXAU + ~0.5 eUSD |

Factory `0x70C62C8b8e801124A4Aa81ce07b637A3e83cb919` · NPM `0xB39002E4033b162fAc607fc3471E205FA2aE5967`  
Doc: `SCROLL-KXAU-EUSD-SALES-SOURCE-LIVE.md`

---

## 11) Live seed snapshot (ops)

| Pool | Seed |
|--|--|
| Base GOLD91 Morpho | ~**$1.00** USDC |
| Scroll credit | ~**$0.95** USDC (post-bridge) |
| Base ELE/GOLD Uni V3 | dust sale sources (above) |
| Scroll kXAU/eUSD Uni V3 | dust sale sources (above) |
| Base Hot USDC residual | ops float |

Gold yELE caps: submitted **$14M**; accept after timelock `validAt`.

---

## 12) Non-goals

- Morpho on Scroll  
- Treating ZK attestation as Morpho collateral  
- Routing through retired Cake / wrong eUSD  
- Flash bridging funding gaps  

---

## 13) Reference docs

| Doc | Scope |
|--|--|
| `SCROLL-DOMINION.md` | Scroll credit stack live |
| `SCROLL-GOLD.md` / `SCROLL-GOLD-ENGINE.md` | Gold rail + mint |
| `ELE-GOLD-SALES-SOURCE-LIVE.md` | Base Uni V3 sale sources |
| `SCROLL-KXAU-EUSD-SALES-SOURCE-LIVE.md` | Scroll Uni V3 sale sources |
| `KING-SAVE-SHEET.md` | Base Morpho / yRSS sheet |
| `OWN-CURATOR-MOAT.md` | Curator doctrine |
| `VAULT-V2-LIVE.md` | V2 owner / exit |
| `FLASH-POLICY.md` / `NO-RECYCLE-UNTIL-EXIT.md` | Capital discipline |
| `OPS-FREEZE.md` / `CHIEF-ECONOMIC-KILL-GATES.md` | Kill gates |
