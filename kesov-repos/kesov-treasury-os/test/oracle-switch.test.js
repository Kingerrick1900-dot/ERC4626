/** Oracle switch unit tests — no RPC */

import assert from 'assert';
import { resolveRssPrimary, configuredRssSource, quoteToken1ForToken0 } from '../src/oracle/sources.js';

const selfSet = {
  id: 'rss_fixed_1usd',
  kind: 'self-set',
  priceRaw: '1000000000000000000000000000000000000',
  stale: false,
  ready: true,
  tag: 'internal-synthetic',
};

const twapNotReady = {
  id: 'rss_cbbtc_uniswap_twap',
  kind: 'uniswap-twap',
  ready: false,
  blockers: ['pool_liquidity_zero'],
  stale: false,
  tag: 'external-priced',
};

const twapReady = {
  id: 'rss_cbbtc_uniswap_twap',
  kind: 'uniswap-twap',
  ready: true,
  blockers: [],
  stale: false,
  priceRaw: '123',
  tag: 'external-priced',
};

assert.strictEqual(configuredRssSource({}), 'self-set');
assert.strictEqual(configuredRssSource({ rss_price_source: 'uniswap-twap' }), 'uniswap-twap');

{
  const p = resolveRssPrimary({ rss_price_source: 'self-set' }, selfSet, twapReady);
  assert.strictEqual(p.source, 'self-set');
  assert.strictEqual(p.rssTag, 'internal-synthetic');
  assert.strictEqual(p.armed, true);
}

{
  // Policy wants TWAP but pool not ready → hold self-set
  const p = resolveRssPrimary(
    { rss_price_source: 'uniswap-twap', rss_twap_require_ready: true },
    selfSet,
    twapNotReady,
  );
  assert.strictEqual(p.source, 'self-set');
  assert.strictEqual(p.rssTag, 'internal-synthetic');
  assert.strictEqual(p.fallback, true);
  assert.strictEqual(p.armed, false);
}

{
  // TWAP ready + policy → external-priced
  const p = resolveRssPrimary(
    { rss_price_source: 'uniswap-twap', rss_twap_require_ready: true },
    selfSet,
    twapReady,
  );
  assert.strictEqual(p.source, 'uniswap-twap');
  assert.strictEqual(p.rssTag, 'external-priced');
  assert.strictEqual(p.armed, true);
}

// Tick quote smoke (known-range tick)
{
  const q = quoteToken1ForToken0(-566706);
  assert.ok(typeof q === 'bigint');
  assert.ok(q >= 0n);
}

console.log('ok — oracle switchable source tests passed');
