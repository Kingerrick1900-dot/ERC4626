#!/usr/bin/env bash
# Prints Day-3 / Day-7 / Day-14 follow-up bodies for King to paste-send.
# Usage: bash script/desk_followup_send.sh AnchorX|Conflux|SBI 3|7|14
set -euo pipefail
DESK="${1:?desk}"
DAY="${2:?day}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASE=$(echo "$DESK" | tr '[:lower:]' '[:upper:]')
BODY="$ROOT/deployments/ke-sov/sell/followups/D${DAY}.txt"
OUTREACH="$ROOT/deployments/ke-sov/sell/OUTREACH-${CASE}.eml"
[ -f "$BODY" ] || { echo "missing $BODY"; exit 1; }
[ -f "$OUTREACH" ] || { echo "missing $OUTREACH"; exit 1; }
TO=$(rg -m1 '^To:' "$OUTREACH" | sed 's/^To: //')
SUBJ=$(rg -m1 '^Subject:' "$BODY" | sed 's/^Subject: //')
echo "=== SEND THIS ==="
echo "To: $TO"
echo "From: efthompson008@gmail.com"
echo "Subject: $SUBJ"
echo "--- body ---"
sed "s/\[Desk\]/$DESK/" "$BODY" | sed '1d'
echo "=== END ==="
