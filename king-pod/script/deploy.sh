#!/usr/bin/env bash
# King Pod — Phase A deploy helpers (Base). Does NOT run broken handoff math.
set -euo pipefail

RPC="${BASE_RPC:?set BASE_RPC}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY for 0x6708…}"
RSS="${RSS_TOKEN:-0x7a305D07B537359cf468eAea9bb176E5308bC337}"
USDC="${USDC_TOKEN:-0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913}"
KING="${KING_WALLET:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"

echo "Deploy KingPodFactory…"
# forge create … (wired after broadcast script verified on fork)
echo "See script/Deploy.s.sol — run:"
echo "  forge script script/Deploy.s.sol:Deploy --rpc-url \$BASE_RPC --broadcast --private-key \$PRIVATE_KEY"
echo "Then: rss approve pod; pod.bootstrap(20979000000000000000000000000, 5000000000000)"
echo "SPEC: free USDC after bootstrap ≈ 0. 12% team cut is Phase C only."
