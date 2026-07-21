#!/usr/bin/env bash
# Compile Circom → R1CS/WASM, Groth16 setup, export Solidity verifier.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CIRCOM="${CIRCOM:-circom}"
NODE_MODULES="$ROOT/node_modules"
BUILD="$ROOT/build"
CIRCUIT="$ROOT/circuits/reserves.circom"
PTAU="$BUILD/pot14_final.ptau"

mkdir -p "$BUILD"
export PATH="/usr/local/bin:$HOME/bin:$PATH"

echo "== compile =="
"$CIRCOM" "$CIRCUIT" --r1cs --wasm --sym -o "$BUILD" -l "$NODE_MODULES"

echo "== ptau (powers of tau 14) =="
if [[ ! -f "$PTAU" ]]; then
  npx snarkjs powersoftau new bn128 14 "$BUILD/pot14_0000.ptau" -v
  npx snarkjs powersoftau contribute "$BUILD/pot14_0000.ptau" "$BUILD/pot14_0001.ptau" --name="king" -e="kingdom-reserves-efa1"
  npx snarkjs powersoftau prepare phase2 "$BUILD/pot14_0001.ptau" "$PTAU"
fi

echo "== groth16 setup =="
npx snarkjs groth16 setup "$BUILD/reserves.r1cs" "$PTAU" "$BUILD/reserves_0000.zkey"
npx snarkjs zkey contribute "$BUILD/reserves_0000.zkey" "$BUILD/reserves_final.zkey" --name="king" -e="kingdom-zkey-efa1"
npx snarkjs zkey export verificationkey "$BUILD/reserves_final.zkey" "$BUILD/verification_key.json"

echo "== export solidity verifier =="
npx snarkjs zkey export solidityverifier "$BUILD/reserves_final.zkey" "$BUILD/Groth16Verifier.sol"
# Place under src for forge
mkdir -p "$ROOT/../src/zk"
# snarkjs exports Solidity 0.8 with contract Groth16Verifier — wrap name
cp "$BUILD/Groth16Verifier.sol" "$ROOT/../src/zk/Groth16Verifier.sol"

echo "== done =="
ls -la "$BUILD" | head -30
