#!/usr/bin/env bash
# Work mode: when hard USDC hits King hot → seed desk → eliteFlashClose (railBps=0) → vault.
# No recycle. No empty-market borrow. No fake plans. Fire only on real USDC.
set -euo pipefail
RPC="${BASE_RPC:-https://mainnet.base.org}"
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
KING=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
VAULT=0xA1aFcb46a64C9173519180458C1cF302179c832a
DESK=0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF
CLOSER=0x39D8636f94e55a123fAA536C2aF09cAA9A1e1a41
MIN=100000 # $0.10
PRICE=50000
POLL="${DRY_POLL_SECS:-5}"
gas=(--gas-price 8000000 --priority-gas-price 2000000)

bal() { cast call "$1" "balanceOf(address)(uint256)" "$2" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}'; }
log() { echo "[$(date -u +%H:%M:%S)] $*"; }

log "WORK vault=$(bal $USDC $VAULT) desk=$(bal $USDC $DESK) king=$(bal $USDC $KING)"

while true; do
  KING_U=$(bal $USDC $KING)
  DESK_U=$(bal $USDC $DESK)

  if [[ "${KING_U:-0}" -ge "$MIN" ]]; then
    log "SEED $KING_U"
    cast send $USDC "approve(address,uint256)" $DESK "$KING_U" \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" "${gas[@]}" >/dev/null
    cast send $DESK "seed(uint256)" "$KING_U" \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" "${gas[@]}" >/dev/null
    DESK_U=$(bal $USDC $DESK)
  fi

  if [[ "${DESK_U:-0}" -ge "$MIN" ]]; then
    B=$DESK_U
    RSS_FILL=$(python3 -c "print($B * 10**18 // $PRICE)")
    RSS_COLL=$(python3 -c "print(($RSS_FILL * 100) // 70)")
    log "FIRE B=$B → vault"
    cast send $CLOSER "eliteFlashClose(uint256,uint256,uint256)" "$RSS_COLL" "$B" "$RSS_FILL" \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" "${gas[@]}"
    log "DONE vault=$(bal $USDC $VAULT) desk=$(bal $USDC $DESK)"
    continue
  fi

  sleep "$POLL"
done
