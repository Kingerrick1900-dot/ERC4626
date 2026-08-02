#!/usr/bin/env bash
# HF monitor — RSS/WETH + RSS/cbBTC Morpho positions
# Alert if HF_raw < 1.60; fail if HF_raw < 1.55
set -euo pipefail
RPC="${BASE_RPC:-https://mainnet.base.org}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
ORA_W=0x3BB87B8ef3Df289C82540F89DE3e4f7762Ed4A98
ORA_C=0x7c60830200D14F7cDd020bd1c0Aa10d6F254bd0b
IDW=0x6d0c2531ad3078b19f569d3d9b48fb9348682a1b769f726c4196e6091a3c35e9
IDC=0x88fb488074c9f9f3acaa5f84a2f4181bc371defa66ff4a9e42e1e5f0d563be0e

pxW=$(cast call "$ORA_W" 'price()(uint256)' --rpc-url "$RPC" | awk '{print $1}')
pxC=$(cast call "$ORA_C" 'price()(uint256)' --rpc-url "$RPC" | awk '{print $1}')
mapfile -t POSW < <(cast call "$MORPHO" 'position(bytes32,address)(uint256,uint128,uint128)' "$IDW" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
mapfile -t POSC < <(cast call "$MORPHO" 'position(bytes32,address)(uint256,uint128,uint128)' "$IDC" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
mapfile -t MKTW < <(cast call "$MORPHO" 'market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)' "$IDW" --rpc-url "$RPC" | awk '{print $1}')
mapfile -t MKTC < <(cast call "$MORPHO" 'market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)' "$IDC" --rpc-url "$RPC" | awk '{print $1}')

python3 - "$pxW" "$pxC" "${POSW[*]}" "${POSC[*]}" "${MKTW[*]}" "${MKTC[*]}" <<'PY'
import sys
pxW=int(sys.argv[1]); pxC=int(sys.argv[2])
posw=list(map(int,sys.argv[3].split())); posc=list(map(int,sys.argv[4].split()))
mktw=list(map(int,sys.argv[5].split())); mktc=list(map(int,sys.argv[6].split()))
def ta(sh,a,s): return 0 if s==0 else sh*a//s
debtW=ta(posw[1],mktw[2],mktw[3]); debtC=ta(posc[1],mktc[2],mktc[3])
cw,cc=posw[2],posc[2]
collW=cw*pxW//10**36; collC=cc*pxC//10**36
hfW=collW/debtW if debtW else float('inf')
hfC=collC/debtC if debtC else float('inf')
print(f'oracle WETH USD~{1e36/pxW:.2f} | cbBTC USD~{1e26/pxC:.2f}')
print(f'WETH  HF_raw={hfW:.4f} collRSS={cw/1e18:.2f} debt={debtW/1e18:.6f}')
print(f'cbBTC HF_raw={hfC:.4f} collRSS={cc/1e18:.2f} debt={debtC/1e8:.6f}')
alert = hfW < 1.60 or hfC < 1.60
fail = hfW < 1.55 or hfC < 1.55
if alert: print('ALERT: HF_raw < 1.60')
if fail:
    print('FAIL: HF_raw < 1.55')
    raise SystemExit(2)
print('OK: HF_raw >= 1.55')
PY
