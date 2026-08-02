#!/usr/bin/env bash
# Encode Merkl MORPHOVAULT campaign for yELEPAN-USDC (Elepan rewards).
# Usage: ./script/merkl/encode_yelepan.sh [start_delay_sec]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
ELE="${ELE:-0x50639C42E2FFDEC4F68FB468968a55b3Af944583}"
YELE="${YELE:-0x61bfD6F7df1f72427F472144d043c25d742D145E}"
RPC="${RPC:-https://mainnet.base.org}"
DELAY="${1:-7200}"
NOW="$(cast block latest --rpc-url "$RPC" --field timestamp)"
START=$((NOW + DELAY))
END=$((START + 28 * 86400))
OUT_DIR="$ROOT/script/merkl"
BODY="$(cat <<EOF
[{
  "distributionChainId": 8453,
  "campaignId": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "amount": "400000000000000",
  "computeChainId": 8453,
  "creator": "$HOT",
  "startTimestamp": $START,
  "rewardToken": "$ELE",
  "distributionMethodParameters": {
    "distributionMethod": "DUTCH_AUCTION",
    "distributionSettings": {}
  },
  "campaignType": 56,
  "endTimestamp": $END,
  "blacklist": [],
  "whitelist": [],
  "forwarders": [],
  "targetToken": "$YELE"
}]
EOF
)"
curl -sS -X POST "https://api.merkl.xyz/v4/config/encode/batch" \
  -H 'content-type: application/json' \
  -H 'accept: application/json' \
  -H 'user-agent: Mozilla/5.0' \
  -H 'origin: https://studio.merkl.xyz' \
  -H 'referer: https://studio.merkl.xyz/' \
  --data-binary "$BODY" >"$OUT_DIR/yelepan-encode-batch.json"
python3 - <<PY
import json
from pathlib import Path
p = Path("$OUT_DIR/yelepan-encode-batch.json")
d = json.loads(p.read_text())
args = d["payloads"][0]["args"]
fee = d["payloads"][0].get("fee")
print(f"START_TS={args['startTimestamp']}")
print(f"CAMPAIGN_DATA={args['campaignData']}")
print(f"DURATION={args['duration']}")
print(f"FEE_RATE_BASE9={fee}")
print(f"AMOUNT={args['amount']}")
env = Path("$OUT_DIR/yelepan-fire.env")
env.write_text(
    f"export START_TS={args['startTimestamp']}\n"
    f"export CAMPAIGN_DATA={args['campaignData']}\n"
)
print(f"wrote {env}")
PY
