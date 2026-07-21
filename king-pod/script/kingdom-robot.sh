#!/usr/bin/env bash
# KINGDOM ROBOT — polls chain, fires legal plays when gates pass. No fortress. No thumb-twiddling.
#
# Modes:
#   ROBOT_MODE=watch     scoreboard only (default)
#   ROBOT_MODE=fire      auto-fire when AUTO_FIRE=1 + keys + KING_OK/KING_GO in env
#
# One-shot bundle (peel + zero BRETT + arm RSS + slash Dutch):
#   LANDING_PRIVATE_KEY=... PRIVATE_KEY=... KING_OK=1 KING_GO=1 AUTO_FIRE=1 \
#     ROBOT_MODE=fire ROBOT_ONCE=ops bash script/kingdom-robot.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
LAND=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
RSS77=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
BRETT_M=0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16
DESK=0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
BOND=0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039
DUTCH=0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81

ROBOT_MODE="${ROBOT_MODE:-watch}"
AUTO_FIRE="${AUTO_FIRE:-0}"
POLL_SECS="${POLL_SECS:-90}"
HOT_FLOOR="${HOT_USDC_FLOOR:-10000000}"   # $10 ops float
MIN_LOAN_FIRE="${MIN_FIRE_USDC:-100000000}" # $100 accessible borrow
TARGET_LOAN="${TARGET_USDC:-500000000000}"
PEEL_TARGET="${PEEL_TO_HOT:-5000000}"
LAND_RESERVE="${LAND_RESERVE:-1000000}"
ROBOT_ONCE="${ROBOT_ONCE:-}"

last_desk=0
last_bond=0
last_dutch=0

usd() { python3 -c "print(f'\${int('$1')/1e6:,.2f}')"; }

idle_usdc() {
  local mkt="$1"
  mapfile -t lines < <(cast call "$MORPHO" \
    "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" \
    "$mkt" --rpc-url "$RPC")
  python3 -c "sup=int('${lines[0]}'.split()[0]); bor=int('${lines[2]}'.split()[0]); print(sup-bor if sup>bor else 0)"
}

debt_usdc() {
  local mkt="$1" who="$2"
  mapfile -t p < <(cast call "$MORPHO" "position(bytes32,address)(uint256,uint128,uint128)" "$mkt" "$who" --rpc-url "$RPC")
  mapfile -t m < <(cast call "$MORPHO" "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" "$mkt" --rpc-url "$RPC")
  python3 -c "
bor=int('${p[1]}'.split()[0]); bA=int('${m[2]}'.split()[0]); bS=int('${m[3]}'.split()[0])
print(bor*bA//bS if bS else 0)
"
}

morpho_coll() {
  cast call "$MORPHO" "position(bytes32,address)(uint256,uint128,uint128)" "$1" "$HOT" --rpc-url "$RPC" \
    | sed -n '3p' | awk '{print $1}'
}

fire_script() {
  local name="$1"
  shift
  echo ">>> FIRE $name"
  if [[ "$AUTO_FIRE" != "1" ]]; then
    echo "    (dry — set AUTO_FIRE=1 to broadcast)"
    return 0
  fi
  [[ -n "${PRIVATE_KEY:-}" ]] || { echo "PRIVATE_KEY missing"; return 1; }
  "$@" --rpc-url "$RPC" --broadcast --slow -vv
}

robot_ops_bundle() {
  echo "=== ROBOT OPS BUNDLE ==="
  local env_args=(KING_OK=1 KING_GO=1 FIRE_OPS=1)
  [[ -n "${LANDING_PRIVATE_KEY:-}" ]] && env_args+=(LANDING_PRIVATE_KEY="$LANDING_PRIVATE_KEY")
  env_args+=(PEEL_TO_HOT="$PEEL_TARGET" LAND_RESERVE="$LAND_RESERVE")
  if [[ "$AUTO_FIRE" == "1" ]]; then
    env "${env_args[@]}" forge script script/FireKingdomOps.s.sol --rpc-url "$RPC" --broadcast --slow -vv
  else
    echo "DRY bundle — sim each step:"
    echo "  peel:   LANDING_PRIVATE_KEY + FirePeelLanding"
    echo "  brett:  FireZeroBrettDust (needs hot USDC)"
    echo "  arm:    FireArmCreditLine POST_RSS=1M"
    echo "  slash:  FireSlashDutch DUTCH_FLOOR=850000"
    echo "Set AUTO_FIRE=1 KING_OK=1 KING_GO=1 FIRE_OPS=1 to broadcast bundle"
  fi
}

cycle() {
  local hot land idle77 dB coll77 desk_r bond_r dutch_r dutch_p
  hot=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
  land=$(cast call "$USDC" "balanceOf(address)(uint256)" "$LAND" --rpc-url "$RPC" | awk '{print $1}')
  idle77=$(idle_usdc "$RSS77")
  dB=$(debt_usdc "$BRETT_M" "$HOT")
  coll77=$(morpho_coll "$RSS77")
  desk_r=$(cast call "$DESK" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
  bond_r=$(cast call "$BOND" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
  dutch_r=$(cast call "$DUTCH" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
  dutch_p=$(cast call "$DUTCH" "currentPrice()(uint256)" --rpc-url "$RPC" | awk '{print $1}')

  echo ""
  echo "=== KINGDOM ROBOT $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "hotUsdc=$(usd "$hot") landUsdc=$(usd "$land") idleRSS77=$(usd "$idle77")"
  echo "brettDebt=$(usd "$dB") rss77Coll=$(python3 -c "print(int('$coll77')/1e18)")"
  echo "raised desk=$(usd "$desk_r") bond=$(usd "$bond_r") dutch=$(usd "$dutch_r") dutchPx=\$$(python3 -c "print(f'{int('$dutch_p')/1e6:.4f}')")"
  echo "mode=$ROBOT_MODE autoFire=$AUTO_FIRE"

  # Commerce wins
  if python3 -c "import sys; sys.exit(0 if int('$desk_r') > int('$last_desk') else 1)"; then
    echo "COMMERCE: Desk fill +$(usd "$(python3 -c "print(int('$desk_r')-int('$last_desk'))")")"
  fi
  if python3 -c "import sys; sys.exit(0 if int('$bond_r') > int('$last_bond') else 1)"; then
    echo "COMMERCE: Bond fill +$(usd "$(python3 -c "print(int('$bond_r')-int('$last_bond'))")")"
  fi
  if python3 -c "import sys; sys.exit(0 if int('$dutch_r') > int('$last_dutch') else 1)"; then
    echo "COMMERCE: Dutch fill +$(usd "$(python3 -c "print(int('$dutch_r')-int('$last_dutch'))")")"
  fi
  last_desk=$desk_r; last_bond=$bond_r; last_dutch=$dutch_r

  [[ "$ROBOT_MODE" == "watch" ]] && return 0

  # TRIGGER A: hot broke — peel if Landing key present
  if python3 -c "import sys; sys.exit(0 if int('$hot') < int('$HOT_FLOOR') and int('$land') > int('$LAND_RESERVE') else 1)"; then
    echo "TRIGGER: hot below floor — peel Landing"
    if [[ -n "${LANDING_PRIVATE_KEY:-}" ]]; then
      fire_script peel env KING_OK=1 KING_GO=1 FIRE_PEEL=1 \
        PEEL_TO_HOT="$PEEL_TARGET" LAND_RESERVE="$LAND_RESERVE" \
        LANDING_PRIVATE_KEY="$LANDING_PRIVATE_KEY" \
        forge script script/FirePeelLanding.s.sol
    else
      echo "    need LANDING_PRIVATE_KEY on cold wallet"
    fi
  fi

  # TRIGGER B: BRETT dust + hot has USDC
  if python3 -c "import sys; sys.exit(0 if int('$dB') > 0 and int('$hot') >= int('$dB') else 1)"; then
    echo "TRIGGER: zero BRETT dust"
    fire_script brett-zero env KING_OK=1 KING_GO=1 FIRE_BRETT_ZERO=1 \
      forge script script/FireZeroBrettDust.s.sol
  fi

  # TRIGGER C: RSS77 unarmed — post 1M coll (no borrow until idle)
  if [[ "$coll77" == "0" ]] && python3 -c "import sys; sys.exit(0 if int('$(debt_usdc "$RSS77" "$HOT")') == 0 else 1)"; then
    echo "TRIGGER: arm RSS77 credit line (coll only)"
    fire_script arm env KING_GO=1 FIRE_ARM=1 forge script script/FireArmCreditLine.s.sol
  fi

  # TRIGGER D: Morpho idle — accessible loan to Hot
  if python3 -c "import sys; sys.exit(0 if int('$idle77') >= int('$MIN_LOAN_FIRE') else 1)"; then
    echo "TRIGGER: accessible loan capture"
    borrow="$idle77"
    if python3 -c "import sys; sys.exit(0 if int('$idle77') > int('$TARGET_LOAN') else 1)"; then
      borrow="$TARGET_LOAN"
    fi
    fire_script loan env KING_OK=1 KING_GO=1 FIRE_LOAN=1 RECEIVER="$HOT" \
      BORROW_USDC="$borrow" MIN_BORROW="$MIN_LOAN_FIRE" \
      forge script script/FireAccessibleLoan.s.sol
  fi

  # TRIGGER E: dutch price drifted up — slash back to floor bait (once per day max in practice)
  if [[ "${SLASH_DUTCH:-0}" == "1" ]]; then
    echo "TRIGGER: slash Dutch (SLASH_DUTCH=1)"
    fire_script slash env KING_OK=1 FIRE_SLASH=1 DUTCH_FLOOR="${DUTCH_FLOOR:-850000}" \
      forge script script/FireSlashDutch.s.sol
  fi
}

if [[ "$ROBOT_ONCE" == "ops" ]]; then
  robot_ops_bundle
  exit 0
fi

if [[ "$ROBOT_ONCE" == "status" ]]; then
  bash script/plays-status.sh
  bash script/return-path-status.sh
  exit 0
fi

echo "KINGDOM ROBOT — poll=${POLL_SECS}s mode=$ROBOT_MODE"
echo "Set ROBOT_MODE=fire AUTO_FIRE=1 + keys for live fire. LIVE-FIRE-LAW applies."

while true; do
  cycle
  [[ -n "$ROBOT_ONCE" ]] && break
  sleep "$POLL_SECS"
done
