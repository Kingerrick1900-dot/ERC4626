#!/usr/bin/env bash
# Scribe fire duty: whenever King/desk holds USDC, slam eliteFlashClose into vault.
# No lectures. Poll → harvest → seed → fire → repeat.
set -euo pipefail
RPC="${BASE_RPC:-https://mainnet.base.org}"
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
KING=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
VAULT=0xA1aFcb46a64C9173519180458C1cF302179c832a
DESK=0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF
CLOSER=0x2192251a8FD4a31843fDE1222C43Ac0ad64ccD25
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
MID=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
MIN=100000 # $0.10
PRICE=50000
POLL="${POLL_SECS:-20}"

bal() { cast call "$1" "balanceOf(address)(uint256)" "$2" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}'; }
log() { echo "[$(date -u +%H:%M:%S)] $*"; }

log "FIRE DUTY armed vault=$(bal $USDC $VAULT)"

while true; do
  # harvest Morpho leftover shares if any
  SHARES=$(cast call $MORPHO "position(bytes32,address)(uint256,uint128,uint128)" $MID $KING --rpc-url $RPC 2>/dev/null | awk 'NR==1{print $1}')
  if [[ "${SHARES:-0}" =~ ^[0-9]+$ ]] && [[ "$SHARES" -gt 100 ]]; then
    log "harvest shares=$SHARES"
    cast send $MORPHO \
      "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)" \
      "(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,0x7a305D07B537359cf468eAea9bb176E5308bC337,0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e,0x46415998764C29aB2a25CbeA6254146D50D22687,770000000000000000)" \
      0 "$SHARES" $KING $KING \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
      --gas-price 6000000 --priority-gas-price 1000000 >/dev/null || true
  fi

  KING_U=$(bal $USDC $KING)
  DESK_U=$(bal $USDC $DESK)
  if [[ "${KING_U:-0}" -ge "$MIN" ]]; then
    log "seed desk $KING_U"
    cast send $USDC "approve(address,uint256)" $DESK "$KING_U" \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
      --gas-price 6000000 --priority-gas-price 1000000 >/dev/null || true
    cast send $DESK "seed(uint256)" "$KING_U" \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
      --gas-price 6000000 --priority-gas-price 1000000 >/dev/null || true
    DESK_U=$(bal $USDC $DESK)
  fi

  if [[ "${DESK_U:-0}" -ge "$MIN" ]]; then
    B=$DESK_U
    RSS_FILL=$(python3 -c "print($B * 10**18 // $PRICE)")
    RSS_COLL=$(python3 -c "print(($RSS_FILL * 100) // 70)")
    log "FIRE B=$B fill=$RSS_FILL coll=$RSS_COLL"
    if cast send $CLOSER "eliteFlashClose(uint256,uint256,uint256)" "$RSS_COLL" "$B" "$RSS_FILL" \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
      --gas-price 6000000 --priority-gas-price 1000000; then
      log "HIT vault=$(bal $USDC $VAULT)"
    else
      log "FIRE_REVERT — retry next poll"
    fi
  else
    log "watching vault=$(bal $USDC $VAULT) desk=0 king=0"
  fi
  sleep "$POLL"
done
