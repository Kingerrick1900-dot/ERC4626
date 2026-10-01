#!/usr/bin/env bash
# ySYNTH first-borrower flywheel — pays eUSD boost for first $5M borrowed against eUSD.
# Trigger: Morpho market totalBorrowAssets >= $5M. Gate B must pass if GATE set.
set -euo pipefail
RPC="${BASE_RPC_URL:-${BASE_RPC:-https://mainnet.base.org}}"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
EUSD="${EUSD:-0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a}"
MORPHO="${MORPHO:-0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb}"
MARKET="${MARKET:-0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd}"
GATE="${GATE:-}"
BOOST_EUSD="${BOOST_EUSD:-50000000000000000000000}" # 50k eUSD
TRIGGER_BORROW="${TRIGGER_BORROW:-5000000000000}" # $5M @ 6dp
FIRST_BORROWER="${FIRST_BORROWER:-}"
export PATH="${HOME}/.foundry/bin:${PATH}"

borrow=$(cast call "$MORPHO" "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" "$MARKET" --rpc-url "$RPC" | sed -n '3p' | awk '{print $1}')
echo "market_borrow_raw=$borrow"
echo "trigger_raw=$TRIGGER_BORROW"

if [ -n "$GATE" ]; then
  cast call "$GATE" "assertCanFlywheel()(bool)" --rpc-url "$RPC" >/dev/null || {
    echo "GATE_B_LOCKED — no borrower boost until Exit > \$500k confirmed"
    exit 0
  }
fi

python3 -c "import sys; sys.exit(0 if int('$borrow') >= int('$TRIGGER_BORROW') else 1)" || {
  echo "BORROWER FLYWHEEL ARMED — waiting for \$5M borrowed against eUSD. No pay yet."
  exit 0
}

if [ -z "$FIRST_BORROWER" ]; then
  echo "TRIGGER MET. Set FIRST_BORROWER=0x... and HOT_KEY=... to pay boost."
  exit 0
fi

: "${HOT_KEY:?set HOT_KEY}"
bal=$(cast call "$EUSD" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
python3 -c "import sys; sys.exit(0 if int('$bal') >= int('$BOOST_EUSD') else 1)" || {
  echo "HOT eUSD $bal < boost $BOOST_EUSD — abort"
  exit 1
}

echo "Paying borrower boost $BOOST_EUSD eUSD → $FIRST_BORROWER"
cast send "$EUSD" "transfer(address,uint256)" "$FIRST_BORROWER" "$BOOST_EUSD" \
  --private-key "$HOT_KEY" --rpc-url "$RPC" --legacy --gas-price "${GAS_PRICE:-5000000}"
if [ -n "$GATE" ]; then
  cast send "$GATE" "recordFlywheel(address,uint256,bool)" "$FIRST_BORROWER" "$BOOST_EUSD" true \
    --private-key "$HOT_KEY" --rpc-url "$RPC" --legacy --gas-price "${GAS_PRICE:-5000000}" || true
fi
echo "BORROWER_BOOST_PAID"
