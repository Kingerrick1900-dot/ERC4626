# FIRE — Cancel nonce → Steakhouse redeem → spark ETH

**Mode:** Fire (executed) · redeem blocked on spark dust  
**Chain:** Base `8453`  
**HOT:** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
**Steakhouse USDC MetaMorpho:** `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183`  
**Landing (spark source):** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`

---

## Done — cancel

| Step | Nonce | Tx | Result |
|--|--|--|--|
| Cancel stuck slot | **2124** | [`0xa09211c925cfa495b2cbdd32a0ad9dec1ac0f11839cdb9ac2df74e6665a5b304`](https://basescan.org/tx/0xa09211c925cfa495b2cbdd32a0ad9dec1ac0f11839cdb9ac2df74e6665a5b304) | Included · `gasUsed=21000` · status `0` (EIP-7702 DeleGator rejects bare self-call at 21k) · **nonce advanced** |
| Clear follow-on | **2125** | [`0xdb86c549afaf765273046dbec6253574566b10e21d90a55455769bf503aaf4d0`](https://basescan.org/tx/0xdb86c549afaf765273046dbec6253574566b10e21d90a55455769bf503aaf4d0) | Included · nonce → **2126** |

**HOT code (EIP-7702):** `0xef010063c0c19a282a1b52b07dd5a65b58948a07dae32b`  
**Delegate:** MetaMask `EIP7702StatelessDeleGator` · EntryPoint `0x0000000071727De22E5E9d8BAf0edAc6f37da032`

Bare `value=0` cancels burn gas and advance nonce; they are not “success” calls under 7702. Prefer cancel `to=0x000…001` with **`gas-limit ≥ 100000`** once spark returns.

---

## Blocked — redeem

| Field | Value |
|--|--|
| Steakhouse shares (HOT) | `1,039,817,338,775,128,256` |
| `previewRedeem` | **`1,146,268` USDC** (6dp) ≈ **$1.146** |
| HOT ETH after cancels | **`13,359,308,588` wei** (~1.34e-8 ETH) |
| Redeem estimate | ~`392,141` gas |
| Need @ ~6e6 wei gasPrice | ~`2.35e12` wei (~0.00000235 ETH / **~$0.007**) |
| Landing ETH | **`145,265,926,165,994` wei** (~0.000145 ETH) — **covers** |

Ultra-low-GP redeem (`gp=25234`, hash `0x67d44f36…`) submitted; **not included** (Base floor ~0.003–0.006 gwei). Nonce **2126** may still hold a underpriced mempool ghost — replace after top-up.

---

## Next lift (one cast from Landing, then fire script)

```bash
# 1) From Landing key — tip HOT ≥ 0.00001 ETH (leaves Landing buffer)
cast send 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 \
  --value 10000000000000 \
  --private-key $LANDING_KEY --rpc-url https://mainnet.base.org --legacy \
  --gas-price 8000000 --gas-limit 120000

# 2) From HOT — redeem + swap + payroll
FIRE=1 ./king-pod/script/fire_steak_spark.sh
```

Payroll target: `CrownKingAgent.firePayroll(10_000_000e18)` @ `0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA`.

---

## Identity

```
cancel(2124,2125) ✓  →  redeem($1.146 USDC) ⊥ dust  →  Landing tip ≥ 2.4e12 wei  →  fire_steak_spark
```
