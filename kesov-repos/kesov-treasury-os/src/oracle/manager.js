/** Oracle Manager — freshness, tags, switchable RSS primary (self-set → Uni TWAP) */

import { ADDR, MARKETS } from '../config.js';
import { oraclePrice, morphoMarket } from '../rpc.js';
import {
  readSelfSetRss,
  readUniswapRssCbtcTwap,
  resolveRssPrimary,
  configuredRssSource,
  UNI_V3,
} from './sources.js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadPolicy() {
  const p = join(__dirname, '..', '..', 'policy', 'default.json');
  return JSON.parse(readFileSync(p, 'utf8'));
}

/**
 * Build Oracle Manager snapshot.
 * Always reads self-set + Uni TWAP candidate; policy selects primary.
 * RSS stays internal-synthetic under self-set; becomes external-priced only when
 * primary successfully switches to a ready Uniswap TWAP.
 */
export async function collectOracles(nowSec = Math.floor(Date.now() / 1000)) {
  const policy = loadPolicy();
  const staleLimit = policy.oracle_staleness_sec ?? 3600;

  const selfSet = await readSelfSetRss();
  const uniTwap = await readUniswapRssCbtcTwap({
    pool: policy.rss_uni_twap_pool || UNI_V3.RSS_CBTC_POOL,
    twapSeconds: policy.rss_uni_twap_seconds ?? 1800,
    minLiquidity: policy.rss_uni_twap_min_liquidity ?? 1,
    minCardinality: policy.rss_uni_twap_min_cardinality ?? 2,
  });

  const primary = resolveRssPrimary(policy, selfSet, uniTwap);

  /** @type {object[]} */
  const feeds = [
    { ...selfSet, role: primary.source === 'self-set' ? 'primary' : 'standby' },
    { ...uniTwap, role: primary.source === 'uniswap-twap' ? 'primary' : 'candidate' },
  ];

  // Morpho composite oracles (RSS×loan) — loan leg external; RSS leg follows primary tag in Accounting
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
      role: 'morpho-composite',
      note: `Composite Morpho oracle (view). Live Morpho still uses Fixed $1 RSS leg until King flips on-chain oracle. Control-plane primary=${primary.source}.`,
    });
  }

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

  const anyStale = feeds.some(
    (f) => (f.role === 'primary' || f.tag === 'external-priced') && f.stale && f.role !== 'standby',
  );
  // Staleness for kill-switch: primary feed stale, or external morpho composites stale
  const primaryStale = primary.feed?.stale === true;
  const compositeStale = feeds.some((f) => f.role === 'morpho-composite' && f.stale);

  return {
    asOf: new Date(nowSec * 1000).toISOString(),
    staleLimitSec: staleLimit,
    anyExternalStale: primaryStale || compositeStale,
    syntheticRssFixedOk: Boolean(selfSet.priceRaw),
    rssPriceSource: {
      configured: configuredRssSource(policy),
      active: primary.source,
      armed: primary.armed,
      fallback: primary.fallback === true,
      rssTag: primary.rssTag,
      note: primary.note,
      twapReady: uniTwap.ready === true,
      twapBlockers: uniTwap.blockers || [],
      pool: uniTwap.address,
    },
    feeds,
    marketHeartbeats: heartbeats,
  };
}

/**
 * Whether Accounting should treat an asset as internal-synthetic.
 * RSS follows Oracle Manager primary switch; kUSD stays synthetic until King says otherwise.
 */
export function isInternalSyntheticAsset(symbol, policy = loadPolicy(), oracleSnap = null) {
  const sym = String(symbol).toUpperCase();
  if (sym === 'RSS' && oracleSnap?.rssPriceSource?.rssTag) {
    return oracleSnap.rssPriceSource.rssTag === 'internal-synthetic';
  }
  const list = policy.internal_synthetic_assets || ['RSS', 'kUSD'];
  return list.map((s) => s.toUpperCase()).includes(sym);
}

export { configuredRssSource, resolveRssPrimary, UNI_V3 };
