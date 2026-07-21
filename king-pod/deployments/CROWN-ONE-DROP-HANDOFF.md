# CrownOneDrop — Build Handoff (Base)

One transaction: pull RSS → mint kUSD on Crown CDP → Aero stable swap → USDC to Landing → `ProofEmitted`.

Stack is **Foundry** (not Hardhat). Chain config lives in `foundry.toml` + script constants (`8453` Base).

## Package

| Component | File | Purpose |
|-----------|------|---------|
| Core contract | `src/CrownOneDrop.sol` | One-drop sequence + proof event |
| Deploy script | `script/FireDeployOneDrop.s.sol` | Deploy on Base |
| Execute script | `script/FireOneDropExecute.s.sol` | King execute (gated) |
| Test suite | `test/CrownOneDrop.t.sol` | Unit verify mint → Landing USDC |
| Proof schema | `deployments/proof.json` | Event shape / post-execute fill |

## Live wiring (constructor)

| Arg | Address |
|-----|---------|
| Morpho Blue | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| Aero Router | `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43` |
| Aero Factory | `0x420DD381b31aEf6683db6B902084cB0FFECe40Da` |
| kUSD | `0x0FEA62084A024544891f03035E85401C2C886c1b` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| RSS | `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| CrownCdp | `0x9F9356dd8B17f58d03f3Db84e81541cdABBD5768` |
| Landing (cold) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Fixed $1 oracle | `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` |
| IRM | `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV (Morpho optional) | `770000000000000000` (77%) |

Primary mint is **Crown CDP** (live). Morpho `supplyCollateral` is optional book presence via `morphoPost`.

## Deploy

```bash
cd king-pod
KING_OK=1 FIRE_ONEDROP_DEPLOY=1 forge script script/FireDeployOneDrop.s.sol:FireDeployOneDrop \
  --rpc-url "$BASE_RPC" --broadcast --chain 8453
```

Optional verify:

```bash
forge verify-contract <ADDRESS> src/CrownOneDrop.sol:CrownOneDrop --chain 8453 \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address,address,address,address,address,uint256)" \
  0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb \
  0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43 \
  0x420DD381b31aEf6683db6B902084cB0FFECe40Da \
  0x0FEA62084A024544891f03035E85401C2C886c1b \
  0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  0x7a305D07B537359cf468eAea9bb176E5308bC337 \
  0x9F9356dd8B17f58d03f3Db84e81541cdABBD5768 \
  0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357 \
  0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e \
  0x46415998764C29aB2a25CbeA6254146D50D22687 \
  770000000000000000)
```

## Execute (King only)

Requires `KING_OK=1 KING_GO=1 FIRE_ONEDROP=1`. Aero kUSD/USDC depth is thin (~$6 seed) — large swaps fail until deepened. Prefer ZK Advance / desk fill for $700k Landing until pool depth exists.

```bash
ONEDROP=<addr> RSS_AMT=<wei> KUSD_AMT=<6dp> USDC_MIN=0 MORPHO_POST=0 \
KING_OK=1 KING_GO=1 FIRE_ONEDROP=1 \
forge script script/FireOneDropExecute.s.sol:FireOneDropExecute \
  --rpc-url "$BASE_RPC" --broadcast --chain 8453
```

`execute(rssAmount, kusdAmount, usdcOutMin, morphoPost)` from hot after RSS approve.

## Deployment record

| Field | Value |
|-------|-------|
| CrownOneDrop | _pending deploy_ |
| Deploy tx | _pending_ |
| Chain | Base `8453` |
| Owner / hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

Broadcast: `broadcast/FireDeployOneDrop.s.sol/8453/run-latest.json` (after fire).

## Proof event

```solidity
event ProofEmitted(
    address indexed borrower,
    uint256 collateralPosted,
    uint256 kusdMinted,
    uint256 usdcReceived,
    uint256 timestamp
);
```

Fill `deployments/proof.json` from the execute receipt. On-chain, immutable, queryable.
