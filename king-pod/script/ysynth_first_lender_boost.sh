#!/usr/bin/env bash
# ySYNTH first-lender flywheel — NO NEW CONTRACTS.
# Pays boosted eUSD from HOT inventory to the first lender address(es) into ySYNTH-USDC.
# Trigger: when vault totalAssets >= $1M USDC (raw 1000000000000), boost unlocks.
set -euo pipefail
RPC="${BASE_RPC_URL:-${BASE_RPC:-https://mainnet.base.org}}"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
YSYNTH="${YSYNTH:-0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C}"
EUSD="${EUSD:-0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a}"
USDC="${USDC:-0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913}"
# Boost: 50_000 eUSD (18dp) to first lender when $1M TVL hit — King sets FIRST_LENDER
BOOST_EUSD="${BOOST_EUSD:-50000000000000000000000}"
TRIGGER_USDC="${TRIGGER_USDC:-1000000000000}" # $1M @ 6dp
FIRST_LENDER="${FIRST_LENDER:-}"
PATH_BIN="${HOME}/.foundry/bin:${PATH}"
export PATH="$PATH_BIN"

ta=$(cast call "$YSYNTH" "totalAssets()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
echo "ySYNTH_totalAssets_raw=$ta"
echo "trigger_raw=$TRIGGER_USDC"

python3 -c "import sys; sys.exit(0 if int('$ta') >= int('$TRIGGER_USDC') else 1)" || {
  echo "FLY WHEEL ARMED — waiting for first \$1M into ySYNTH. No pay yet."
  echo "Lender path: deposit USDC into $YSYNTH (King Synth eUSD USDC Vault / ySYNTH-USDC)"
  echo "Boost when triggered: $BOOST_EUSD eUSD wei → FIRST_LENDER"
  exit 0
}

if [ -z "$FIRST_LENDER" ]; then
  echo "TRIGGER MET. Set FIRST_LENDER=0x... and HOT_KEY=... to pay boost."
  exit 0
fi

: "${HOT_KEY:?set HOT_KEY}"
bal=$(cast call "$EUSD" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
python3 -c "import sys; sys.exit(0 if int('$bal') >= int('$BOOST_EUSD') else 1)" || {
  echo "HOT eUSD balance $bal < boost $BOOST_EUSD — abort"
  exit 1
}

echo "Paying boost $BOOST_EUSD eUSD → $FIRST_LENDER"
cast send "$EUSD" "transfer(address,uint256)" "$FIRST_LENDER" "$BOOST_EUSD" \
  --private-key "$HOT_KEY" --rpc-url "$RPC" --legacy --gas-price "${GAS_PRICE:-5000000}"
echo "BOOST_PAID"
cast call "$EUSD" "balanceOf(address)(uint256)" "$FIRST_LENDER" --rpc-url "$RPC"
