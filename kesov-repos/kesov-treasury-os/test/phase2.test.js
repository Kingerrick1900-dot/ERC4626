/** Phase 2 unit tests — Policy Engine + Risk Controller (no RPC) */

import { loadPolicy, validatePolicy, maxAllocation, isSyntheticAsset } from '../src/policy/engine.js';
import { evaluateIntent } from '../src/risk/controller.js';
import { evaluateSentinel } from '../src/sentinel/rules.js';
import { IntentQueue } from '../src/intent/queue.js';
import assert from 'assert';

const policy = loadPolicy();
validatePolicy(policy);
assert.strictEqual(isSyntheticAsset(policy, 'RSS'), true);
assert.strictEqual(isSyntheticAsset(policy, 'USDC'), false);
assert.strictEqual(maxAllocation(policy, 'morpho_usdc'), 0n);

// Risk: approve clean repay
{
  const d = evaluateIntent(
    { action: 'repay', params: { postIntentHfRaw: 1.7 }, attempts: 0 },
    { pauseNewIntents: false },
    policy,
  );
  assert.strictEqual(d.approved, true, d.reason);
}

// Risk: reject HF below min
{
  const d = evaluateIntent(
    { action: 'borrow', params: { postIntentHfRaw: 1.2 }, attempts: 0 },
    {},
    policy,
  );
  assert.strictEqual(d.approved, false);
  assert.match(d.reason, /hf:below_min/);
}

// Risk: circular exposure
{
  const d = evaluateIntent(
    { action: 'deposit', params: { circularExposure: 0.1, asset: 'RSS', protocol: 'morpho_cbbtc', amount: '1' }, attempts: 0 },
    {},
    policy,
  );
  assert.strictEqual(d.approved, false);
  assert.match(d.reason, /circular/);
}

// Risk: sentinel pause blocks non-unwind
{
  const d = evaluateIntent(
    { action: 'borrow', params: {}, attempts: 0 },
    { pauseNewIntents: true },
    policy,
  );
  assert.strictEqual(d.approved, false);
  assert.match(d.reason, /pause_new_intents/);
}

// Risk: king-signed unwind allowed under pause
{
  const d = evaluateIntent(
    { action: 'repay', params: { kingSigned: true }, attempts: 0 },
    { pauseNewIntents: true },
    policy,
  );
  assert.strictEqual(d.approved, true, d.reason);
}

// Risk: unauthorized forceDeallocate
{
  const d = evaluateIntent(
    { action: 'deallocate', params: { forceDeallocate: true }, attempts: 0 },
    { caller: '0x1111111111111111111111111111111111111111' },
    policy,
  );
  assert.strictEqual(d.approved, false);
  assert.match(d.reason, /unauthorized_caller/);
}

// Risk: USDC protocol capped at zero
{
  const d = evaluateIntent(
    {
      action: 'borrow',
      params: { protocol: 'morpho_usdc', amount: '1000000', postIntentHfRaw: 2.0 },
      attempts: 0,
    },
    { currentAllocation: { morpho_usdc: '0' } },
    policy,
  );
  assert.strictEqual(d.approved, false);
  assert.match(d.reason, /capped_zero|above_max/);
}

// Risk: forbid blending synthetic into external solvency
{
  const d = evaluateIntent(
    { action: 'deposit', params: { blendSyntheticIntoExternalSolvency: true }, attempts: 0 },
    {},
    policy,
  );
  assert.strictEqual(d.approved, false);
}

// Risk: wrong tag on RSS
{
  const d = evaluateIntent(
    { action: 'deposit', params: { asset: 'RSS', tag: 'external-priced' }, attempts: 0 },
    {},
    policy,
  );
  assert.strictEqual(d.approved, false);
}

// Sentinel: stale oracle pauses
{
  const s = evaluateSentinel({ oracle: { anyExternalStale: true } }, policy);
  assert.strictEqual(s.pauseNewIntents, true);
  assert.ok(s.reasons.some((r) => r.includes('oracle')));
}

// Intent queue retry → dead letter
{
  const q = new IntentQueue();
  const i = q.enqueue({ source: 'test', action: 'deposit', params: {} });
  q.riskGate(i.id, {}, policy);
  // may be rejected by circular/etc — force approved path
  const i2 = q.enqueue({
    source: 'test',
    action: 'repay',
    params: { postIntentHfRaw: 2 },
  });
  const { decision } = q.riskGate(i2.id, {}, policy);
  assert.strictEqual(decision.approved, true);
  q.recordAttempt(i2.id, { ok: false, error: 'sim fail 1' });
  q.recordAttempt(i2.id, { ok: false, error: 'sim fail 2' });
  const dead = q.recordAttempt(i2.id, { ok: false, error: 'sim fail 3' });
  assert.strictEqual(dead.status, 'dead');
  assert.strictEqual(q.deadLetter.length, 1);
}

console.log('ok — policy + risk + sentinel + intent queue tests passed');
