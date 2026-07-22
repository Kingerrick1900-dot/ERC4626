/** Risk Controller — real-time Intent evaluator against Policy + Accounting + Oracle */

import { loadPolicy, maxAllocation, isSyntheticAsset } from '../policy/engine.js';
import { MAX_INTENT_RETRIES } from '../types.js';

/**
 * @typedef {Object} RiskContext
 * @property {object} [snapshot] Accounting snapshot
 * @property {object} [oracle] Oracle manager output
 * @property {boolean} [pauseNewIntents] Sentinel pause flag
 * @property {Record<string, string|bigint>} [currentAllocation] protocol → amount
 * @property {number} [proposedCircularExposure] 0..1 fraction of kUSD redeployed into RSS markets
 * @property {number} [postIntentHfRaw]
 * @property {number} [postIntentUtilization]
 * @property {string} [caller] for deallocate / force paths
 */

/**
 * @typedef {Object} RiskDecision
 * @property {boolean} approved
 * @property {string} reason
 * @property {'approve'|'reject'} verdict
 */

/**
 * Pure approve/reject. Does not mutate state. Logged reason always returned.
 *
 * @param {import('../types.js').Intent | object} intent
 * @param {RiskContext} ctx
 * @param {object} [policy]
 * @returns {RiskDecision}
 */
export function evaluateIntent(intent, ctx = {}, policy = loadPolicy()) {
  const note = (approved, reason) => ({
    approved,
    verdict: approved ? 'approve' : 'reject',
    reason,
  });

  if (!intent || !intent.action) {
    return note(false, 'missing intent.action');
  }

  // Sentinel pause — new Intents only; does not block King-signed unwind paths
  if (ctx.pauseNewIntents) {
    const unwind =
      intent.action === 'repay' ||
      intent.action === 'collateral_topup' ||
      intent.params?.kingSigned === true;
    if (!unwind) {
      return note(false, 'sentinel:pause_new_intents (unwind requires kingSigned)');
    }
  }

  // Oracle staleness on external feeds
  const oracle = ctx.oracle || ctx.snapshot?.oracle;
  if (oracle?.anyExternalStale && !intent.params?.allowStaleOracle) {
    const defensive =
      intent.action === 'repay' || intent.action === 'collateral_topup' || intent.action === 'deallocate';
    if (!defensive) {
      return note(false, 'oracle:external_stale');
    }
  }

  // HF floor
  const hf = ctx.postIntentHfRaw ?? intent.params?.postIntentHfRaw;
  if (hf != null && Number(hf) < policy.min_hf_raw) {
    return note(false, `hf:below_min (${hf} < ${policy.min_hf_raw})`);
  }

  // Utilization cap
  const util = ctx.postIntentUtilization ?? intent.params?.postIntentUtilization;
  if (util != null && Number(util) > policy.max_utilization) {
    return note(false, `util:above_max (${util} > ${policy.max_utilization})`);
  }

  // Circular exposure — kUSD back into RSS markets
  const circ =
    ctx.proposedCircularExposure ?? intent.params?.circularExposure ?? 0;
  if (Number(circ) > policy.max_circular_exposure) {
    return note(
      false,
      `circular:above_max (${circ} > ${policy.max_circular_exposure}) — kUSD must not inflate RSS solvency`,
    );
  }

  // Block intents that would blend synthetic into external solvency reporting
  if (intent.params?.blendSyntheticIntoExternalSolvency === true) {
    return note(false, 'accounting:forbid_blend_synthetic_external');
  }

  // Protocol allocation caps
  const protocol = intent.params?.protocol;
  if (protocol && intent.params?.amount != null) {
    const cap = maxAllocation(policy, protocol);
    const current = BigInt(ctx.currentAllocation?.[protocol] ?? 0);
    const add = BigInt(intent.params.amount);
    if (cap > 0n && current + add > cap) {
      return note(false, `allocation:above_max (${protocol})`);
    }
    if (cap === 0n && add > 0n && (intent.action === 'deposit' || intent.action === 'allocate' || intent.action === 'borrow')) {
      // explicit zero cap = blocked (e.g. morpho_usdc)
      if (Object.prototype.hasOwnProperty.call(policy.max_allocation_by_protocol || {}, protocol)) {
        return note(false, `allocation:protocol_capped_zero (${protocol})`);
      }
    }
  }

  // forceDeallocate / deallocate from non-King → reject at Risk (Sentinel also watches chain)
  if (
    (intent.action === 'deallocate' || intent.params?.forceDeallocate === true) &&
    ctx.caller
  ) {
    const king = String(policy.king_hot).toLowerCase();
    if (String(ctx.caller).toLowerCase() !== king && !intent.params?.kingSigned) {
      return note(false, 'forceDeallocate:unauthorized_caller');
    }
  }

  // Offense gated
  if (
    !policy.auto_offense &&
    intent.params?.offense === true &&
    !intent.params?.kingSigned
  ) {
    return note(false, 'offense:requires_king_or_policy_auto_offense');
  }

  // Synthetic asset awareness
  const asset = intent.params?.asset;
  if (asset && isSyntheticAsset(policy, asset)) {
    // allow but annotate — Strategy should mark tag
    if (intent.params?.tag === 'external-priced') {
      return note(false, `tag:RSS/kUSD_must_be_internal-synthetic`);
    }
  }

  // Retry budget awareness (queue layer also enforces)
  if ((intent.attempts ?? 0) > MAX_INTENT_RETRIES) {
    return note(false, 'queue:dead_letter_retries_exhausted');
  }

  return note(true, 'ok');
}
