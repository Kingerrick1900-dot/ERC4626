#!/usr/bin/env bash
# Deploy CrownVaultSolver (no willFromZero). Requires KING_GO=1 PRIVATE_KEY BASE_RPC_URL.
set -euo pipefail
: "${KING_GO:?set KING_GO=1}"
: "${PRIVATE_KEY:?}"
: "${BASE_RPC_URL:?}"
cd "$(dirname "$0")/.."
CREDIT="${CREDIT:-0x5568fE662363d7F3fa52349A99C9e19C6616B60d}"
exec forge script script/FireCrownVaultSolver.s.sol:FireCrownVaultSolverDeploy \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow "$@"
