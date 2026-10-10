#!/usr/bin/env bash
# Compile + Groth16 setup for wallet_reserves (bind kUSD+RSS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CIRCOM="${CIRCOM:-circom}"
NODE_MODULES="$ROOT/node_modules"
BUILD="$ROOT/build"
CIRCUIT="$ROOT/circuits/wallet_reserves.circom"
PTAU="$BUILD/pot14_final.ptau"

mkdir -p "$BUILD"
export PATH="/usr/local/bin:$HOME/bin:$PATH"

echo "== compile wallet_reserves =="
"$CIRCOM" "$CIRCUIT" --r1cs --wasm --sym -o "$BUILD" -l "$NODE_MODULES"

echo "== ptau =="
if [[ ! -f "$PTAU" ]]; then
  npx snarkjs powersoftau new bn128 14 "$BUILD/pot14_0000.ptau" -v
  npx snarkjs powersoftau contribute "$BUILD/pot14_0000.ptau" "$BUILD/pot14_0001.ptau" --name="king" -e="kingdom-wallet-bind"
  npx snarkjs powersoftau prepare phase2 "$BUILD/pot14_0001.ptau" "$PTAU"
fi

echo "== groth16 setup =="
npx snarkjs groth16 setup "$BUILD/wallet_reserves.r1cs" "$PTAU" "$BUILD/wallet_reserves_0000.zkey"
npx snarkjs zkey contribute "$BUILD/wallet_reserves_0000.zkey" "$BUILD/wallet_reserves_final.zkey" --name="king" -e="kingdom-wallet-zkey"
npx snarkjs zkey export verificationkey "$BUILD/wallet_reserves_final.zkey" "$BUILD/wallet_reserves_vkey.json"

echo "== export solidity verifier =="
npx snarkjs zkey export solidityverifier "$BUILD/wallet_reserves_final.zkey" "$BUILD/Groth16WalletVerifier.sol"
# Rename contract
sed -i 's/contract Groth16Verifier/contract Groth16WalletVerifier/' "$BUILD/Groth16WalletVerifier.sol"
mkdir -p "$ROOT/../src/zk"
cp "$BUILD/Groth16WalletVerifier.sol" "$ROOT/../src/zk/Groth16WalletVerifier.sol"

echo "== done =="
ls -la "$BUILD"/wallet_reserves* "$BUILD"/Groth16WalletVerifier.sol 2>/dev/null | head
