/** Sentinel — deterministic pause rules (pause new Intents only) */

import { loadPolicy } from '../policy/engine.js';

/**
 * @typedef {Object} SentinelInput
 * @property {object} [oracle]
 * @property {object} [snapshot]
 * @property {number} [hfRaw]
 * @property {number} [utilization]
 * @property {number} [liquidityUsd]
 * @property {boolean} [protocolPaused]
 * @property {string} [forceDeallocateCaller] last observed caller
 * @property {boolean} [kingForceDeallocate]
 */

/**
 * @typedef {Object} SentinelState
 * @property {boolean} pauseNewIntents
 * @property {string[]} reasons
 * @property {string} asOf
 */

/**
 * Evaluate pause rules. Does NOT authorize unwinds — those need King signature.
 * @param {SentinelInput} input
 * @param {object} [policy]
 * @returns {SentinelState}
 */
export function evaluateSentinel(input = {}, policy = loadPolicy()) {
  /** @type {string[]} */
  const reasons = [];

  if (policy.pause_new_intents_default) {
    reasons.push('policy:pause_new_intents_default');
  }

  const oracle = input.oracle || input.snapshot?.oracle;
  if (oracle?.anyExternalStale) {
    reasons.push('oracle:external_stale');
  }

  if (input.protocolPaused) {
    reasons.push('protocol:paused');
  }

  const hf = input.hfRaw;
  if (hf != null && hf < policy.min_hf_raw) {
    reasons.push(`hf:below_min (${hf})`);
  }

  const util = input.utilization;
  if (util != null && util > policy.max_utilization) {
    reasons.push(`util:above_max (${util})`);
  }

  const liq = input.liquidityUsd;
  if (liq != null && liq < (policy.min_liquidity_buffer_usd ?? 0)) {
    reasons.push(`liquidity:below_floor (${liq})`);
  }

  // Unauthorized forceDeallocate caller → pause new intents + alert
  if (input.forceDeallocateCaller) {
    const king = String(policy.king_hot).toLowerCase();
    const caller = String(input.forceDeallocateCaller).toLowerCase();
    if (caller !== king && !input.kingForceDeallocate) {
      reasons.push(`forceDeallocate:unauthorized_caller (${caller})`);
    }
  }

  return {
    pauseNewIntents: reasons.length > 0,
    reasons,
    asOf: new Date().toISOString(),
  };
}
