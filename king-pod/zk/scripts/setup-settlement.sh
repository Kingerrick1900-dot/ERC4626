#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build proofs

echo "[1/5] circom settlement.circom"
circom circuits/settlement.circom --r1cs --wasm --sym -o build -l node_modules

if [[ ! -f build/pot14_final.ptau ]]; then
  echo "NEED build/pot14_final.ptau (reuse from wallet setup)"
  exit 1
fi

echo "[2/5] zkey new"
npx snarkjs groth16 setup build/settlement.r1cs build/pot14_final.ptau build/settlement_0000.zkey

echo "[3/5] zkey contribute (ceremony-lite)"
echo "king-settlement-contrib" | npx snarkjs zkey contribute build/settlement_0000.zkey build/settlement_final.zkey --name="king" -v

echo "[4/5] export vkey"
npx snarkjs zkey export verificationkey build/settlement_final.zkey build/settlement_vkey.json

echo "[5/5] export solidity verifier"
npx snarkjs zkey export solidityverifier build/settlement_final.zkey ../src/zk/Groth16SettlementVerifier.sol
# Rename contract for clarity
sed -i 's/contract Groth16Verifier/contract Groth16SettlementVerifier/' ../src/zk/Groth16SettlementVerifier.sol

echo "SETTLEMENT_SETUP_OK"
