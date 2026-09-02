#!/usr/bin/env bash
# Emergency Morpho self-repay (RSS1200 or eUSD market). No flash. No multisig.
# Usage: MARKET=rss AMT=1000000000 PRIVATE_KEY=0x… bash king-pod/script/FireMorphoSelfRepayCast.sh
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
GUARD="${SELF_GUARD:?set SELF_GUARD address}"
AMT="${AMT:?set AMT USDC raw}"
MARKET="${MARKET:-rss}"

RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
ORACLE_RSS=0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e
IRM=0x46415998764C29aB2a25CbeA6254146D50D22687
LLTV_RSS=770000000000000000

EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a
ORACLE_EUSD=0x44bc82a9ADaF15edCa1bc0030Bdf7500af5CC750
LLTV_EUSD=860000000000000000

if [[ "$MARKET" == "rss" ]]; then
  COLL=$RSS; ORACLE=$ORACLE_RSS; LLTV=$LLTV_RSS
else
  COLL=$EUSD; ORACLE=$ORACLE_EUSD; LLTV=$LLTV_EUSD
fi

echo "approve guard USDC $AMT"
cast send "$USDC" "approve(address,uint256)" "$GUARD" "$AMT" --rpc-url "$RPC" --private-key "$PK" --gas-limit 80000
sleep 6
echo "selfRepay"
cast send "$GUARD" \
  "selfRepay((address,address,address,address,uint256),uint256)" \
  "($USDC,$COLL,$ORACLE,$IRM,$LLTV)" "$AMT" \
  --rpc-url "$RPC" --private-key "$PK" --gas-limit 500000
echo DONE
