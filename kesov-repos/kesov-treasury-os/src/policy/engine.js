/** Policy Engine — static rule config only (no Intent evaluation) */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_PATH = join(__dirname, '..', '..', 'policy', 'default.json');

/**
 * @typedef {Object} Policy
 * @property {number} min_hf_raw
 * @property {number} alert_hf_raw
 * @property {number} max_utilization
 * @property {number} min_liquidity_buffer_usd
 * @property {number} oracle_staleness_sec
 * @property {number} max_circular_exposure
 * @property {string} force_deallocate_penalty_min_wad
 * @property {string} prefer_loan
 * @property {boolean} auto_defend
 * @property {boolean} auto_offense
 * @property {boolean} pause_new_intents_default
 * @property {string} king_hot
 * @property {string} king_landing
 * @property {string[]} internal_synthetic_assets
 * @property {Record<string, string>} max_allocation_by_protocol
 */

/** @returns {Policy} */
export function loadPolicy(path = DEFAULT_PATH) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

/**
 * Validate policy shape. Throws on hard errors.
 * @param {Policy} policy
 */
export function validatePolicy(policy) {
  const required = [
    'min_hf_raw',
    'max_utilization',
    'oracle_staleness_sec',
    'max_circular_exposure',
    'force_deallocate_penalty_min_wad',
    'internal_synthetic_assets',
  ];
  for (const k of required) {
    if (policy[k] === undefined || policy[k] === null) {
      throw new Error(`policy missing ${k}`);
    }
  }
  if (policy.min_hf_raw < 1) throw new Error('min_hf_raw must be >= 1');
  if (policy.max_utilization < 0 || policy.max_utilization > 1) {
    throw new Error('max_utilization must be in [0,1]');
  }
  if (policy.max_circular_exposure < 0 || policy.max_circular_exposure > 1) {
    throw new Error('max_circular_exposure must be in [0,1]');
  }
  if (!Array.isArray(policy.internal_synthetic_assets) || policy.internal_synthetic_assets.length === 0) {
    throw new Error('internal_synthetic_assets required');
  }
  return true;
}

/**
 * Resolve max allocation for a protocol key (static lookup).
 * @param {Policy} policy
 * @param {string} protocolKey
 * @returns {bigint}
 */
export function maxAllocation(policy, protocolKey) {
  const map = policy.max_allocation_by_protocol || {};
  const v = map[protocolKey];
  if (v == null) return 0n;
  return BigInt(v);
}

/**
 * Whether an asset symbol is tagged internal-synthetic by policy.
 */
export function isSyntheticAsset(policy, symbol) {
  return (policy.internal_synthetic_assets || [])
    .map((s) => s.toUpperCase())
    .includes(String(symbol).toUpperCase());
}
