/** Oracle Manager — freshness + internal vs external tagging */

import { ADDR, MARKETS } from '../config.js';
import { oraclePrice, morphoMarket } from '../rpc.js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadPolicy() {
  const p = join(__dirname, '..', '..', 'policy', 'default.json');
  return JSON.parse(readFileSync(p, 'utf8'));
}

/**
 * @typedef {Object} OracleFeed
 * @property {string} id
 * @property {string} address
 * @property {'internal-synthetic'|'external-priced'} tag
 * @property {string|null} priceRaw
 * @property {number|null} usdHint
 * @property {number|null} lastUpdateSec
 * @property {boolean} stale
 * @property {string} note
 */

/**
 * Build Oracle Manager snapshot.
 * RSS fixed $1.00 feed is always internal-synthetic — never blended into external solvency.
 */
export async function collectOracles(nowSec = Math.floor(Date.now() / 1000)) {
  const policy = loadPolicy();
  const staleLimit = policy.oracle_staleness_sec ?? 3600;

  /** @type {OracleFeed[]} */
  const feeds = [];

  // Fixed RSS $1 — synthetic by doctrine
  const rssFixed = await oraclePrice(ADDR.ORACLE_RSS_FIXED);
  feeds.push({
    id: 'rss_fixed_1usd',
    address: ADDR.ORACLE_RSS_FIXED,
    tag: 'internal-synthetic',
    priceRaw: rssFixed != null ? rssFixed.toString() : null,
    usdHint: 1.0,
    lastUpdateSec: null,
    stale: false,
    note: 'Self-set $1.00 RSS — Accounting tags positions internal-synthetic',
  });

  // Morpho composite oracles (RSS×loan TWAP) — price() is view-computed; no on-feed timestamp.
  // Tag loan-side pricing as external-priced. Staleness = price() unavailable (not Morpho market lastUpdate).
  for (const [id, addr] of [
    ['rss_weth_composite', ADDR.ORACLE_RSS_WETH],
    ['rss_cbbtc_composite', ADDR.ORACLE_RSS_CBTC],
  ]) {
    const price = await oraclePrice(addr);
    feeds.push({
      id,
      address: addr,
      tag: 'external-priced',
      priceRaw: price != null ? price.toString() : null,
      usdHint: null,
      lastUpdateSec: null,
      stale: price == null,
      note: 'Composite Morpho oracle (view). Stale only if price() fails. RSS leg remains synthetic in Accounting.',
    });
  }

  // Optional: Morpho market heartbeats (utilization / interest accrual), not oracle freshness
  const heartbeats = [];
  for (const [id, marketId] of [
    ['market_rss_weth', MARKETS.RSS_WETH],
    ['market_rss_cbbtc', MARKETS.RSS_CBTC],
  ]) {
    const mkt = await morphoMarket(marketId);
    const lastUpdate = mkt ? Number(mkt.lastUpdate) : null;
    const age = lastUpdate != null ? nowSec - lastUpdate : null;
    heartbeats.push({
      id,
      lastUpdateSec: lastUpdate,
      ageSec: age,
      quiet: age != null ? age > staleLimit : true,
    });
  }

  const anyStale = feeds.some((f) => f.tag === 'external-priced' && f.stale);
  const syntheticOk = feeds.find((f) => f.id === 'rss_fixed_1usd')?.priceRaw != null;

  return {
    asOf: new Date(nowSec * 1000).toISOString(),
    staleLimitSec: staleLimit,
    anyExternalStale: anyStale,
    syntheticRssFixedOk: Boolean(syntheticOk),
    feeds,
    marketHeartbeats: heartbeats,
  };
}

export function isInternalSyntheticAsset(symbol, policy = loadPolicy()) {
  const list = policy.internal_synthetic_assets || ['RSS', 'kUSD'];
  return list.map((s) => s.toUpperCase()).includes(String(symbol).toUpperCase());
}
