/** RSS price sources — self-set ($1) and Uniswap V3 TWAP (RSS/cbBTC) */

import { ADDR } from '../config.js';
import { ethCallOk, decodeUint, decodeUintAt, oraclePrice } from '../rpc.js';

/** Uniswap V3 — RSS/cbBTC 1% pool on Base (King discovery lane) */
export const UNI_V3 = {
  FACTORY: '0x33128a8fC17869897dcE68Ed026d694621f6FDfD',
  RSS_CBTC_POOL: '0x9022a130B0798AE6aEf6398404E4B7453873EEC9',
  FEE_1PCT: 10000,
};

const SEL = {
  slot0: '0x3850c7bd',
  liquidity: '0x1a686502',
  observe: '0x883bdbfd',
};

/**
 * @typedef {'self-set'|'uniswap-twap'} RssPriceSource
 */

/**
 * @param {object} policy
 * @returns {RssPriceSource}
 */
export function configuredRssSource(policy) {
  const s = policy?.rss_price_source || 'self-set';
  if (s === 'uniswap-twap') return 'uniswap-twap';
  return 'self-set';
}

/** Self-set Fixed $1.00 RSS oracle (Morpho IOracle price()). */
export async function readSelfSetRss() {
  const priceRaw = await oraclePrice(ADDR.ORACLE_RSS_FIXED);
  return {
    id: 'rss_fixed_1usd',
    kind: 'self-set',
    address: ADDR.ORACLE_RSS_FIXED,
    tag: 'internal-synthetic',
    priceRaw: priceRaw != null ? priceRaw.toString() : null,
    usdHint: 1.0,
    stale: priceRaw == null,
    ready: priceRaw != null,
    blockers: priceRaw == null ? ['self_set_price_unavailable'] : [],
    note: 'Self-set $1.00 — Accounting tags RSS internal-synthetic until primary source switches',
  };
}

/**
 * Decode signed int256 word (Uniswap observe packs int56 as int256).
 * @param {string} hex
 * @param {number} wordIndex
 */
function decodeInt256At(hex, wordIndex) {
  const h = String(hex).replace(/^0x/i, '');
  const slice = h.slice(wordIndex * 64, wordIndex * 64 + 64);
  if (!slice) return 0n;
  let v = BigInt('0x' + slice);
  if (v >= 1n << 255n) v -= 1n << 256n;
  return v;
}

/**
 * Quote cbBTC raw (8dp) for 1e18 RSS at a Uniswap tick.
 * Pool token0=RSS, token1=cbBTC → amount1 = amount0 * sqrtP^2 / 2^192
 * @param {number} tick
 * @param {bigint} [amount0]
 */
export function quoteToken1ForToken0(tick, amount0 = 10n ** 18n) {
  const absTick = BigInt(tick < 0 ? -tick : tick);
  if (absTick > 887272n) throw new Error('tick out of range');

  let ratio =
    (absTick & 0x1n) !== 0n
      ? 0xfffcb933bd6fad37aa2d162d1a594001n
      : 0x100000000000000000000000000000000n;
  const steps = [
    [0x2n, 0xfff97272373d413259a46990580e213an],
    [0x4n, 0xfff2e50f5f656932ef12357cf3c7fdccn],
    [0x8n, 0xffe5caca7e10e4e61c3624eaa0941cd0n],
    [0x10n, 0xffcb9843d60f6159c9db58835c926644n],
    [0x20n, 0xff973b41fa98c081472e6896dfb254c0n],
    [0x40n, 0xff2ea16466c96a3843ec78b326b52861n],
    [0x80n, 0xfe5dee046a99a2a811c461f1969c3053n],
    [0x100n, 0xfcbe86c7900a88aedcffc83b479aa3a4n],
    [0x200n, 0xf987a7253ac413176f2b074cf7815e54n],
    [0x400n, 0xf3392b0822b70005940c7a398e4b70f3n],
    [0x800n, 0xe7159475a2c29b7443b29c7fa6e89d64n],
    [0x1000n, 0xd097f3bdfd2022b8845ad8f792aa5825n],
    [0x2000n, 0xa9f746462d870fdf8a65dc1f90e061e5n],
    [0x4000n, 0x70d869a156d2a1b890bb3df62baf32f7n],
    [0x8000n, 0x31be135f97d08fd981231505542fcfa6n],
    [0x10000n, 0x9aa508b5b7a84e1c677de54f3e99bc9n],
    [0x20000n, 0x5d6af8dedb81196699c329225ee604n],
    [0x40000n, 0x2216e584f5fa1ea926041bedfe98n],
    [0x80000n, 0x48a170391f7dc42444e8fa2n],
  ];
  for (const [mask, mul] of steps) {
    if ((absTick & mask) !== 0n) ratio = (ratio * mul) >> 128n;
  }
  if (tick > 0) ratio = ((1n << 256n) - 1n) / ratio;

  const sqrtPriceX96 = ratio >> 32n;
  const ratioX192 = sqrtPriceX96 * sqrtPriceX96;
  return (ratioX192 * amount0) / (1n << 192n);
}

/**
 * Read Uni V3 RSS/cbBTC TWAP + readiness gates for the primary-source switch.
 * @param {object} [opts]
 */
export async function readUniswapRssCbtcTwap(opts = {}) {
  const pool = opts.pool || UNI_V3.RSS_CBTC_POOL;
  const twapSec = Number(opts.twapSeconds ?? 1800);
  const minLiquidity = BigInt(opts.minLiquidity ?? 1);
  const minCardinality = Number(opts.minCardinality ?? 2);

  const slot0Out = await ethCallOk(pool, SEL.slot0);
  const liqOut = await ethCallOk(pool, SEL.liquidity);

  let sqrtPriceX96 = null;
  let tick = null;
  let observationCardinality = null;
  let observationCardinalityNext = null;
  if (slot0Out && slot0Out !== '0x') {
    sqrtPriceX96 = decodeUintAt(slot0Out, 0);
    let tickWord = decodeUintAt(slot0Out, 1);
    if (tickWord >= 1n << 255n) tickWord -= 1n << 256n;
    tick = Number(tickWord);
    observationCardinality = Number(decodeUintAt(slot0Out, 3));
    observationCardinalityNext = Number(decodeUintAt(slot0Out, 4));
  }

  const liquidity = liqOut && liqOut !== '0x' ? decodeUint(liqOut) : 0n;

  // observe(uint32[] secondsAgos) with [twapSec, 0]
  const obsData =
    SEL.observe +
    '0000000000000000000000000000000000000000000000000000000000000020' +
    '0000000000000000000000000000000000000000000000000000000000000002' +
    twapSec.toString(16).padStart(64, '0') +
    '0000000000000000000000000000000000000000000000000000000000000000';

  const observeOut = await ethCallOk(pool, obsData);

  let twapTick = null;
  let observeOk = false;
  let observeError = null;
  if (observeOut && observeOut !== '0x') {
    try {
      // ABI: offset0, offset1, len, c0, c1, ...
      const len = Number(decodeUintAt(observeOut, 2));
      if (len >= 2) {
        const c0 = decodeInt256At(observeOut, 3);
        const c1 = decodeInt256At(observeOut, 4);
        const delta = c1 - c0;
        const period = BigInt(twapSec);
        let avg = delta / period;
        if (delta < 0n && delta % period !== 0n) avg -= 1n;
        twapTick = Number(avg);
        observeOk = true;
      } else {
        observeError = 'observe returned <2 cumulatives';
      }
    } catch (e) {
      observeError = String(e.message || e);
    }
  } else {
    observeError = 'observe() failed or empty';
  }

  let cbbtcPerRss = null;
  let priceRawMorpho = null;
  if (twapTick != null) {
    try {
      cbbtcPerRss = quoteToken1ForToken0(twapTick, 10n ** 18n);
      // Morpho scale: loan_raw * 1e36 / coll_raw for coll sample 1e18
      priceRawMorpho = (cbbtcPerRss * 10n ** 36n) / 10n ** 18n;
    } catch (e) {
      observeError = String(e.message || e);
    }
  }

  const depthOk = liquidity >= minLiquidity;
  const cardinalityOk = (observationCardinality ?? 0) >= minCardinality;
  const ready = observeOk && depthOk && cardinalityOk && priceRawMorpho != null;

  /** @type {string[]} */
  const blockers = [];
  if (!observeOk) blockers.push('twap_observe_failed');
  if (!depthOk) blockers.push(liquidity === 0n ? 'pool_liquidity_zero' : 'pool_liquidity_below_min');
  if (!cardinalityOk) {
    blockers.push(`cardinality_${observationCardinality ?? 0}_lt_${minCardinality}`);
  }

  return {
    id: 'rss_cbbtc_uniswap_twap',
    kind: 'uniswap-twap',
    address: pool,
    tag: 'external-priced',
    pair: 'RSS/cbBTC',
    fee: UNI_V3.FEE_1PCT,
    twapSeconds: twapSec,
    priceRaw: priceRawMorpho != null ? priceRawMorpho.toString() : null,
    cbbtcPerRssRaw: cbbtcPerRss != null ? cbbtcPerRss.toString() : null,
    usdHint: null,
    twapTick,
    spotTick: tick,
    sqrtPriceX96: sqrtPriceX96 != null ? sqrtPriceX96.toString() : null,
    liquidity: liquidity.toString(),
    observationCardinality,
    observationCardinalityNext,
    stale: !observeOk || priceRawMorpho == null,
    ready,
    blockers,
    note:
      'Uni V3 RSS/cbBTC TWAP on-ramp. Primary switch only when ready (depth + cardinality). Morpho on-chain oracle flip is a separate King order.',
    observeError,
  };
}

/**
 * Resolve which RSS source is primary for Accounting tags.
 * Never auto-flips to TWAP unless policy says so AND feed is ready (unless force).
 *
 * @param {object} policy
 * @param {object} selfSet
 * @param {object} uniTwap
 */
export function resolveRssPrimary(policy, selfSet, uniTwap) {
  const configured = configuredRssSource(policy);
  const requireReady = policy.rss_twap_require_ready !== false;

  if (configured === 'uniswap-twap') {
    if (!requireReady || uniTwap?.ready) {
      return {
        source: 'uniswap-twap',
        feed: uniTwap,
        rssTag: 'external-priced',
        armed: true,
        note: 'Primary = Uniswap TWAP — RSS treated as external-priced',
      };
    }
    return {
      source: 'self-set',
      feed: selfSet,
      rssTag: 'internal-synthetic',
      armed: false,
      fallback: true,
      note: `Policy wants uniswap-twap but not ready (${(uniTwap?.blockers || []).join(',') || 'unknown'}) — holding self-set`,
    };
  }

  return {
    source: 'self-set',
    feed: selfSet,
    rssTag: 'internal-synthetic',
    armed: true,
    note: 'Primary = self-set $1.00 — RSS internal-synthetic',
  };
}
