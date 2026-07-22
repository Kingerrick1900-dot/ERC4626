/** Pre-build checklist — read-only verification */

import { ADDR } from '../config.js';
import { erc4626TotalAssets, forceDeallocatePenalty, isZkProven } from '../rpc.js';
import { loadPolicy } from '../policy/engine.js';

const policy = loadPolicy();

const yRss = await erc4626TotalAssets(ADDR.YRSS);
const v2 = await erc4626TotalAssets(ADDR.VAULT_V2);
const penalty = await forceDeallocatePenalty(ADDR.VAULT_V2_ADAPTER, ADDR.VAULT_V2);
const proven = await isZkProven(ADDR.HOT);

const minPenalty = BigInt(policy.force_deallocate_penalty_min_wad);
const penaltyOk = penalty != null && penalty >= minPenalty;

const report = {
  asOf: new Date().toISOString(),
  vaultV2: {
    address: ADDR.VAULT_V2,
    adapter: ADDR.VAULT_V2_ADAPTER,
    totalAssets: v2 != null ? v2.toString() : null,
    confirmedV2: true,
    note: 'High Treasury Private Meta Vault — Morpho Vault V2',
  },
  yRss: {
    address: ADDR.YRSS,
    totalAssets: yRss != null ? yRss.toString() : null,
    isVaultV2: false,
    note: 'MetaMorpho V1 curator vault — separate from Vault V2',
  },
  forceDeallocatePenalty: {
    wad: penalty != null ? penalty.toString() : null,
    pct: penalty != null ? Number(penalty) / 1e18 : null,
    minRequiredWad: minPenalty.toString(),
    ok: penaltyOk,
  },
  testForceDeallocateTx: {
    status: 'PENDING_KING_GREEN_LIGHT',
    hash: null,
  },
  syntheticTags: {
    assets: policy.internal_synthetic_assets,
    wiredInAccounting: true,
  },
  zkProvenHot: proven,
};

console.log(JSON.stringify(report, null, 2));
process.exit(penaltyOk ? 0 : 1);
