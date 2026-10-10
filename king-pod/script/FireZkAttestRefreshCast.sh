#!/usr/bin/env bash
# Refresh bordersSecure on Base / Polygon / Scroll (attestLive is permissionless).
# Keys: PRIVATE_KEY or SCROLL_KEY (Base+Scroll gas) · POLY_KEY (Polygon)
# FOUNDRY_ETH_RPC_URL overrides cast --rpc-url — unset so Poly/Scroll are real.
set -euo pipefail
export PATH="${HOME}/.foundry/bin:${PATH}"
unset FOUNDRY_ETH_RPC_URL ETH_RPC_URL RPC || true

ZERO=0x0000000000000000000000000000000000000000000000000000000000000000
BASE_RPC="${BASE_RPC_URL_REAL:-https://mainnet.base.org}"
POLY_RPC="${POLY_RPC_URL:-https://polygon-bor-rpc.publicnode.com}"
SCROLL_RPC="${SCROLL_RPC_URL:-https://rpc.scroll.io}"

BASE_ATTEST=0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7
POLY_ATTEST=0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211
SCROLL_ATTEST=0x2ab17e3c00D783F58B106De2fB1723b4915Da257

BASE_PK="${PRIVATE_KEY:-${SCROLL_KEY:?set PRIVATE_KEY or SCROLL_KEY}}"
POLY_PK="${POLY_KEY:?set POLY_KEY}"
SCROLL_PK="${SCROLL_KEY:-$PRIVATE_KEY}"

echo ">>> Base attestLive"
cast send "$BASE_ATTEST" "attestLive(bytes32)" "$ZERO" \
  --private-key "$BASE_PK" --rpc-url "$BASE_RPC" --gas-limit 600000
echo "base borders=$(cast call "$BASE_ATTEST" "bordersSecure()(bool)" --rpc-url "$BASE_RPC") epoch=$(cast call "$BASE_ATTEST" "epoch()(uint256)" --rpc-url "$BASE_RPC")"

echo ">>> Polygon attestLive"
cast send "$POLY_ATTEST" "attestLive(bytes32)" "$ZERO" \
  --private-key "$POLY_PK" --rpc-url "$POLY_RPC" --gas-limit 400000
echo "poly borders=$(cast call "$POLY_ATTEST" "bordersSecure()(bool)" --rpc-url "$POLY_RPC") epoch=$(cast call "$POLY_ATTEST" "epoch()(uint256)" --rpc-url "$POLY_RPC")"

echo ">>> Scroll attestLive"
cast send "$SCROLL_ATTEST" "attestLive(bytes32)" "$ZERO" \
  --private-key "$SCROLL_PK" --rpc-url "$SCROLL_RPC" --gas-limit 300000
echo "scroll borders=$(cast call "$SCROLL_ATTEST" "bordersSecure()(bool)" --rpc-url "$SCROLL_RPC") epoch=$(cast call "$SCROLL_ATTEST" "epoch()(uint256)" --rpc-url "$SCROLL_RPC")"

echo DONE
