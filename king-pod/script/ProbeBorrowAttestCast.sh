#!/usr/bin/env bash
# Probe borders Attest + WalletGate borrow-attest on Base / Polygon / Scroll.
# FOUNDRY_ETH_RPC_URL overrides cast --rpc-url — must unset for L2 reads.
set -euo pipefail
export PATH="${HOME}/.foundry/bin:${PATH}"
unset FOUNDRY_ETH_RPC_URL ETH_RPC_URL RPC || true

BASE_RPC="${BASE_RPC_URL_REAL:-https://mainnet.base.org}"
POLY_RPC="${POLY_RPC_URL:-https://polygon-bor-rpc.publicnode.com}"
SCROLL_RPC="${SCROLL_RPC_URL:-https://rpc.scroll.io}"

BASE_ATTEST=0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7
POLY_ATTEST=0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211
SCROLL_ATTEST=0x2ab17e3c00D783F58B106De2fB1723b4915Da257
GATE=0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579

HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
POLY_DESK=0x31511861a519D6b814Eb20b4A0bcc391e76177dF
SCROLL_HOT=0xca76AE9e29a5F01465D890dc30109cD58B78F864

probe() {
  local name="$1" rpc="$2" attest="$3" subject="$4"
  echo "======== $name ========"
  echo "cid=$(cast chain-id --rpc-url "$rpc")"
  echo "borders=$(cast call "$attest" "bordersSecure()(bool)" --rpc-url "$rpc")"
  echo "epoch=$(cast call "$attest" "epoch()(uint256)" --rpc-url "$rpc")"
  local glen
  glen=$(cast code "$GATE" --rpc-url "$rpc" | wc -c | tr -d ' ')
  if [[ "$glen" -gt 4 ]]; then
    echo "WalletGate@$GATE code_bytes≈$glen"
    echo "isProven=$(cast call "$GATE" "isProven(address)(bool)" "$subject" --rpc-url "$rpc")"
    cast call "$GATE" "attestations(address)(uint256,uint256,bool)" "$subject" --rpc-url "$rpc"
  else
    echo "WalletGate@$GATE ABSENT (borrow attest not ported)"
  fi
}

probe BASE "$BASE_RPC" "$BASE_ATTEST" "$HOT"
probe POLY "$POLY_RPC" "$POLY_ATTEST" "$POLY_DESK"
probe SCROLL "$SCROLL_RPC" "$SCROLL_ATTEST" "$SCROLL_HOT"
echo DONE
