#!/usr/bin/env bash
# Loop the proven $2 elite-flash pattern until kingdom vault hits $700k or rails dry.
# Usage: BASE_RPC=... PRIVATE_KEY=... ./script/loop-to-mark.sh
# Re-run whenever USDC lands on King — each run stacks vault toward the mark.
set -euo pipefail
cd "$(dirname "$0")/.."
RPC="${BASE_RPC:-https://mainnet.base.org}"
MARK_RAW=700000000000
VAULT=0xA1aFcb46a64C9173519180458C1cF302179c832a
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

vault() { cast call "$USDC" "balanceOf(address)(uint256)" "$VAULT" --rpc-url "$RPC" | awk '{print $1}'; }

V=$(vault)
echo "vault_start=$V mark=$MARK_RAW"
if [[ "$V" -ge "$MARK_RAW" ]]; then
  echo "MARK_HIT"
  exit 0
fi

forge script script/LoopEliteToMark.s.sol:LoopEliteToMark \
  --rpc-url "$RPC" \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  -vv

V=$(vault)
echo "vault_end=$V"
if [[ "$V" -ge "$MARK_RAW" ]]; then
  echo "MARK_HIT"
else
  echo "RAILS_DRY_OR_PARTIAL — drop USDC on King and re-run this script"
fi
