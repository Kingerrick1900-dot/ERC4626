#!/usr/bin/env bash
# Encode Merkl Morpho MARKET supply campaign — FIXED_RATE only (no variable dilution).
# Target: RSS/$1200 USDC supply. Reward token default USDC (Merkl-whitelisted).
# Usage: ./script/merkl/encode_rss1200_fixed.sh [start_delay_sec] [budget_usdc_raw]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
USDC="${USDC:-0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913}"
MID="${MID:-0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88}"
RPC="${RPC:-https://mainnet.base.org}"
DELAY="${1:-7200}"
# Default budget $50k USDC raw (6dp) — King overrides
BUDGET="${2:-50000000000}"
NOW="$(cast block latest --rpc-url "$RPC" --field timestamp)"
START=$((NOW + DELAY))
END=$((START + 28 * 86400))
OUT_DIR="$ROOT/script/merkl"
mkdir -p "$OUT_DIR"

# campaignType 18 = commonly used Morpho-related encode path; Studio may remint.
# FIXED_RATE distribution — protects early suppliers.
BODY="$(cat <<EOF
[{
  "distributionChainId": 8453,
  "campaignId": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "amount": "$BUDGET",
  "computeChainId": 8453,
  "creator": "$HOT",
  "startTimestamp": $START,
  "rewardToken": "$USDC",
  "distributionMethodParameters": {
    "distributionMethod": "FIXED_RATE",
    "distributionSettings": {}
  },
  "campaignType": 18,
  "endTimestamp": $END,
  "blacklist": [],
  "whitelist": [],
  "forwarders": [],
  "targetToken": "$USDC",
  "market": "$MID"
}]
EOF
)"
curl -sS -X POST "https://api.merkl.xyz/v4/config/encode/batch" \
  -H 'content-type: application/json' \
  -H 'accept: application/json' \
  -H 'user-agent: Mozilla/5.0' \
  -H 'origin: https://studio.merkl.xyz' \
  -H 'referer: https://studio.merkl.xyz/' \
  --data-binary "$BODY" >"$OUT_DIR/rss1200-encode-batch.json" || true

python3 - <<PY
import json
from pathlib import Path
p = Path("$OUT_DIR/rss1200-encode-batch.json")
raw = p.read_text()
try:
    d = json.loads(raw)
except Exception as e:
    print("ENCODE_FAIL", e, raw[:300])
    raise SystemExit(1)
if "payloads" not in d:
    print("ENCODE_FAIL", raw[:500])
    raise SystemExit(1)
args = d["payloads"][0]["args"]
fee = d["payloads"][0].get("fee")
print(f"START_TS={args['startTimestamp']}")
print(f"CAMPAIGN_DATA={args['campaignData']}")
print(f"DURATION={args['duration']}")
print(f"FEE_RATE_BASE9={fee}")
print(f"AMOUNT={args['amount']}")
env = Path("$OUT_DIR/rss1200-fire.env")
env.write_text(
    f"export START_TS={args['startTimestamp']}\n"
    f"export CAMPAIGN_DATA={args['campaignData']}\n"
    f"export MERKL_BUDGET={args['amount']}\n"
)
print(f"wrote {env}")
print("NOTE= Prefer Merkl Studio Morpho→Market→Supply→FIXED_RATE; paste CAMPAIGN_DATA if API shape drifts.")
PY
