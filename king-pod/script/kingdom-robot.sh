#!/usr/bin/env bash
# KINGDOM ROBOT — loop wallet ops, hot Morpho signer. No Landing key. No fortress.
#
# Wallets:
#   LOOP  0x8d3cfbFc6A276f118579517E4d166e94C66F8585  LOOP_PRIVATE_KEY — fund hot gas/USDC
#   HOT   0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1  PRIVATE_KEY — Morpho, Dutch, RSS
#
# Strike bundle (arm 1M RSS + slash Dutch + optional BRETT zero after loop fund):
#   LOOP_PRIVATE_KEY=... PRIVATE_KEY=... KING_OK=1 KING_GO=1 AUTO_FIRE=1 \
#     ROBOT_ONCE=ops bash script/kingdom-robot.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
LOOP=0x8d3cfbFc6A276f118579517E4d166e94C66F8585
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
HOT_FLOOR="${HOT_USDC_FLOOR:-10000000}"
MIN_LOAN_FIRE="${MIN_FIRE_USDC:-100000000}"
TARGET_LOAN="${TARGET_USDC:-500000000000}"
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
  "$@" --rpc-url "$RPC" --broadcast --slow -vv
}

robot_ops_bundle() {
  echo "=== ROBOT STRIKE OPS (loop + hot) ==="
  local env_args=(KING_OK=1 KING_GO=1 FIRE_OPS=1)
  [[ -n "${LOOP_PRIVATE_KEY:-}" ]] && env_args+=(LOOP_PRIVATE_KEY="$LOOP_PRIVATE_KEY")
  [[ -n "${PRIVATE_KEY:-}" ]] || { echo "PRIVATE_KEY (hot) required"; return 1; }
  env_args+=(PRIVATE_KEY="$PRIVATE_KEY")
  if [[ "$AUTO_FIRE" == "1" ]]; then
    env "${env_args[@]}" forge script script/FireKingdomOps.s.sol --rpc-url "$RPC" --broadcast --slow -vv
  else
    echo "STRIKE: loop fund hot -> arm 1M RSS -> slash Dutch \$0.85 -> zero BRETT if funded"
    echo "Keys: LOOP_PRIVATE_KEY + PRIVATE_KEY | AUTO_FIRE=1 KING_OK=1 KING_GO=1 FIRE_OPS=1"
  fi
}

cycle() {
  local hot land loop_u idle77 dB coll77 desk_r bond_r dutch_r dutch_p hot_eth loop_eth
  hot=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
  land=$(cast call "$USDC" "balanceOf(address)(uint256)" "$LAND" --rpc-url "$RPC" | awk '{print $1}')
  loop_u=$(cast call "$USDC" "balanceOf(address)(uint256)" "$LOOP" --rpc-url "$RPC" | awk '{print $1}')
  hot_eth=$(cast balance "$HOT" --rpc-url "$RPC")
  loop_eth=$(cast balance "$LOOP" --rpc-url "$RPC")
  idle77=$(idle_usdc "$RSS77")
  dB=$(debt_usdc "$BRETT_M" "$HOT")
  coll77=$(morpho_coll "$RSS77")
  desk_r=$(cast call "$DESK" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
  bond_r=$(cast call "$BOND" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
  dutch_r=$(cast call "$DUTCH" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
  dutch_p=$(cast call "$DUTCH" "currentPrice()(uint256)" --rpc-url "$RPC" | awk '{print $1}')

  echo ""
  echo "=== KINGDOM ROBOT $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "loopUsdc=$(usd "$loop_u") loopEth=$(python3 -c "print(f'{int('$loop_eth')/1e18:.5f}')")"
  echo "hotUsdc=$(usd "$hot") hotEth=$(python3 -c "print(f'{int('$hot_eth')/1e18:.5f}')") landUsdc=$(usd "$land")"
  echo "idleRSS77=$(usd "$idle77") rss77Coll=$(python3 -c "print(int('$coll77')/1e18)") brettDebt=$(usd "$dB")"
  echo "raised desk=$(usd "$desk_r") bond=$(usd "$bond_r") dutch=$(usd "$dutch_r") dutchPx=\$$(python3 -c "print(f'{int('$dutch_p')/1e6:.4f}')")"
  echo "mode=$ROBOT_MODE autoFire=$AUTO_FIRE"

  if python3 -c "import sys; sys.exit(0 if int('$desk_r') > int('$last_desk') else 1)"; then
    echo "COMMERCE WIN: Desk +$(usd "$(python3 -c "print(int('$desk_r')-int('$last_desk'))")")"
  fi
  if python3 -c "import sys; sys.exit(0 if int('$bond_r') > int('$last_bond') else 1)"; then
    echo "COMMERCE WIN: Bond +$(usd "$(python3 -c "print(int('$bond_r')-int('$last_bond'))")")"
  fi
  if python3 -c "import sys; sys.exit(0 if int('$dutch_r') > int('$last_dutch') else 1)"; then
    echo "COMMERCE WIN: Dutch +$(usd "$(python3 -c "print(int('$dutch_r')-int('$last_dutch'))")")"
  fi
  last_desk=$desk_r; last_bond=$bond_r; last_dutch=$dutch_r

  [[ "$ROBOT_MODE" == "watch" ]] && return 0

  # PRIORITY 1: Arm 1M RSS credit line (inventory play — not dust)
  if [[ "$coll77" == "0" ]] && python3 -c "import sys; sys.exit(0 if int('$(debt_usdc "$RSS77" "$HOT")') == 0 else 1)"; then
    echo "TRIGGER: ARM 1M RSS77 collateral"
    [[ -n "${PRIVATE_KEY:-}" ]] || { echo "    need PRIVATE_KEY (hot)"; return 0; }
    fire_script arm env KING_GO=1 FIRE_ARM=1 PRIVATE_KEY="$PRIVATE_KEY" \
      forge script script/FireArmCreditLine.s.sol
  fi

  # PRIORITY 2: Morpho idle capture to Hot (real borrow when liquidity faces book)
  if python3 -c "import sys; sys.exit(0 if int('$idle77') >= int('$MIN_LOAN_FIRE') else 1)"; then
    echo "TRIGGER: CAPTURE accessible loan"
    borrow="$idle77"
    if python3 -c "import sys; sys.exit(0 if int('$idle77') > int('$TARGET_LOAN') else 1)"; then
      borrow="$TARGET_LOAN"
    fi
    fire_script loan env KING_OK=1 KING_GO=1 FIRE_LOAN=1 PRIVATE_KEY="$PRIVATE_KEY" \
      RECEIVER="$HOT" BORROW_USDC="$borrow" MIN_BORROW="$MIN_LOAN_FIRE" \
      forge script script/FireAccessibleLoan.s.sol
  fi

  # PRIORITY 3: Loop fund hot when below ops floor
  if python3 -c "import sys; sys.exit(0 if int('$hot') < int('$HOT_FLOOR') else 1)"; then
    if python3 -c "import sys; sys.exit(0 if int('$loop_u') > 1000000 else 1)"; then
      echo "TRIGGER: loop fund hot"
      if [[ -n "${LOOP_PRIVATE_KEY:-}" ]]; then
        fire_script fund env KING_OK=1 KING_GO=1 FIRE_FUND=1 LOOP_PRIVATE_KEY="$LOOP_PRIVATE_KEY" \
          forge script script/FireLoopFundHot.s.sol
      else
        echo "    need LOOP_PRIVATE_KEY on 0x8d3cfbFc…8585"
      fi
    fi
  fi

  # PRIORITY 4: Dutch slash bait (commerce engine)
  if [[ "${SLASH_DUTCH:-0}" == "1" ]]; then
    echo "TRIGGER: slash Dutch floor"
    fire_script slash env KING_OK=1 FIRE_SLASH=1 PRIVATE_KEY="$PRIVATE_KEY" DUTCH_FLOOR="${DUTCH_FLOOR:-850000}" \
      forge script script/FireSlashDutch.s.sol
  fi

  # PRIORITY 5: BRETT dust zero only after hot funded (housekeeping — not the mission)
  if python3 -c "import sys; sys.exit(0 if int('$dB') > 0 and int('$hot') >= int('$dB') else 1)"; then
    echo "TRIGGER: zero BRETT dust (housekeeping)"
    fire_script brett-zero env KING_OK=1 KING_GO=1 FIRE_BRETT_ZERO=1 PRIVATE_KEY="$PRIVATE_KEY" \
      forge script script/FireZeroBrettDust.s.sol
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

echo "KINGDOM ROBOT — loop ops wallet + hot signer. poll=${POLL_SECS}s"
echo "Loop: $LOOP | Hot: $HOT | No Landing key."

while true; do
  cycle
  [[ -n "$ROBOT_ONCE" ]] && break
  sleep "$POLL_SECS"
done
