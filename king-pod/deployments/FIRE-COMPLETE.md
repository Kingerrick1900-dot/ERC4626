# FIRE COMPLETE — Activate · Fire · Finish

**Mode:** FIRE · Base + Polygon + Scroll  
**Decree:** Finish everything we can now  
**Scoreboard:** HOT hard USDC (Base + Poly)

---

## What finished this pass

| Rail | Result |
|--|--|
| ZK borders Base | **attestLive** → bordersSecure **true** · epoch **16** |
| ZK borders Polygon | **attestLive** → bordersSecure **true** · epoch **8** |
| ZK borders Scroll | **attestLive** → bordersSecure **true** · epoch **10** |
| AMO6 stubs | **amoCount = 4** (armed, not tripped) |
| Polygon MATIC→USDC→Credit→HOT | **816015** USDC @ HOT.poly · debt=supply |
| Uni kXAU dust | sold `200000` (8dp) → **7** USDC → Spoils `DUST_UNI` |
| Spoils first campaign | **7** split 2 Cold / 3 Ocean / 2 HOT |

---

## Attest txs

| Chain | Tx | Epoch |
|--|--|--:|
| Base | [`0xc78426fe…6e03`](https://basescan.org/tx/0xc78426fef6da5f7df6c25af80291f1aa879f786cdabb2cf62856e9fe38f76e03) | 16 |
| Polygon | [`0xfddd5efb…19b6`](https://polygonscan.com/tx/0xfddd5efb5ccaacb1414c04200aebd946a53486f63d3ff4f095fe589e36d419b6) | 8 |
| Scroll | [`0x673a76be…57ab`](https://scrollscan.com/tx/0x673a76be2cf89f2fd6aa9eaa1da44a683b032218745aeab4bd8e4159bce457ab) | 10 |

---

## Polygon Credit fire (desk MATIC → HOT USDC)

| Step | Detail | Tx |
|--|--|--|
| WMATIC wrap | desk native → WMATIC | [`0x52e8f406…bf4a`](https://polygonscan.com/tx/0x52e8f40692bf09b0796a1f0691af5c78d099169c6513af2481e9fd2b339fbf4a) |
| Swap | WMATIC→USDC fee 500 · **326015** out (prior leg) | [`0x17e64eb0…f6c2`](https://polygonscan.com/tx/0x17e64eb047840ee49a389a1652b11b5bfce293e9c3c6cd8b0d266f24bfd5f6c2) |
| Supply | Credit `0xe8EF…3B18` | [`0xdc97ace0…9f0c`](https://polygonscan.com/tx/0xdc97ace0c6edb4c90a66a5b69ae6603dfbfacdc075c40e10fe49b9f6033e9f0c) |
| Operator | desk setOperator | [`0x61955a0e…b486`](https://polygonscan.com/tx/0x61955a0eb7e4aa602df02bd0dd38b248edef866a7b4969c3db63cfc6e55cb486) |
| Borrow | `operatorBorrowTo(HOT)` | [`0x808f0d88…4a0c`](https://polygonscan.com/tx/0x808f0d8842605d27fc23bbc9b3380f1be0edbc87d924845b6d06af078f084a0c) |

Credit: `totalSupplyUsdc = totalDebt = 816015` · `maxBorrow(HOT) = 0` (fully drawn).  
Desk MATIC left ≈ `0.197` (gas reserve).

---

## AMO6 widen (pause stubs)

| Stub | Create tx | registerAMO tx |
|--|--|--|
| `0xf8Ef6484…1152` | [`0x90180208…855a`](https://basescan.org/tx/0x90180208a68a47568d1c8f18b459fd551619b92a284884ce55fde61080ad855a) | [`0xcd157600…6f13`](https://basescan.org/tx/0xcd157600f94fd4092422ec6ad489e2582936fca0a6025ade42ae4c87661f6f13) |
| `0x83832Ae8…4c7c` | [`0xb29fcc30…1ded`](https://basescan.org/tx/0xb29fcc30c01fba30b62f21d7b8d509344d46a5ec5ab612aeb4f23d2fb40f1ded) | [`0x06306062…b8bf`](https://basescan.org/tx/0x063060624f23a640cebf0ab7725add92790429711fc092170e595f925bd9b8bf) |
| `0xd0F294eA…37Eb` | [`0x51cf4dcf…352c`](https://basescan.org/tx/0x51cf4dcf89a060f8885510fded9ccd929e0ac46f5e3ae918f4784e748a96352c) | [`0x07644175…2b1c`](https://basescan.org/tx/0x0764417578d1d34ca80694852dc7b7c2e55b5e2ff6485c05064796bef5962b1c) |

Breaker: **armed=true** · **tripped=false** · **amoCount=4**  
MintGate: **canMint=false** · **unlocked=0** · ColdBuffer **bps=3000**

---

## Dust Uni + Spoils prove-live

| Step | Tx |
|--|--|
| `uniSell` 200000 kXAU → 7 USDC | [`0x443536f1…0777`](https://basescan.org/tx/0x443536f12ab0c01b99fd30d12f04dacb89ecab9c8a7a3aa82401ec7f90a70777) |
| `takeSpoil(7, DUST_UNI)` | [`0xc6065474…11a5`](https://basescan.org/tx/0xc60654742d0f0a720391e3dd124c7f6863b0c9d9126264f904d459a5cf8011a5) |

Spoils book: total **7** · Cold **2** · Ocean **3** · HOT **2**.  
Convert `filledUsdc` = **980338**.

---

## Scoreboard (now)

| Meter | Value |
|--|--:|
| **HOT USDC Base** | **2** |
| **HOT USDC Polygon** | **816015** |
| ColdBuffer USDC | **294101** |
| DeepPull USDC (sink) | **697192** |
| Ocean pool USDC | **17527** |
| TWAMM #0 available | ~**4.69e11** (still open @ $9.80) |
| Route B filled (cum) | **980338** |
| bordersSecure | Base **16** · Poly **8** · Scroll **10** |

---

## Already live (prior fires — still green)

- $3M A+B Sweep / Convert / TWAMM — `FIRE-3M-AB.md`  
- AMO6 CircuitBreaker + MintGate + Cold 30% — `FIRE-AMO6-OCEAN.md`  
- Spoils router `0x4dBc…ecd0` · Ocean USDC leg LP **6136635**  

---

## Cannot finish without new inventory

| Blocked | Why |
|--|--|
| USDT · DAI · EURC Ocean legs | No external inventory / venues |
| TWAMM $1.5M fills | Needs external buyers @ ≥ $9.80 |
| Bridge Poly USDC → Base | Dust size; gas > value; leave on Poly scoreboard |
| AMO 1–5 / real pause targets | Stubs registered; real AMOs await capital path |
| Deeper Uni gold | Pool bid exhausted (dust only) |

```
FIRE_COMPLETE=1
BORDERS=base16,poly8,scroll10
AMO_COUNT=4
HOT_USDC_BASE=2
HOT_USDC_POLY=816015
SPOILS_PROVED=DUST_UNI
NEXT=TWAMM_fills→widen_USDT_DAI_EURC→AMO_1_5
```
