/** Accounting Layer — polls wallets + Morpho + CDP; tags synthetic vs external */

import { ADDR, MARKETS } from '../config.js';
import {
  erc20Balance,
  erc20Decimals,
  erc4626TotalAssets,
  morphoPosition,
  morphoMarket,
  forceDeallocatePenalty,
  isZkProven,
  ethCallBatch,
  decodeUint,
  SEL,
  encAddr,
} from '../rpc.js';
import { collectOracles, isInternalSyntheticAsset } from '../oracle/manager.js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadPolicy() {
  return JSON.parse(readFileSync(join(__dirname, '..', '..', 'policy', 'default.json'), 'utf8'));
}

function toHuman(amount, decimals) {
  const d = BigInt(decimals);
  const base = 10n ** d;
  const whole = amount / base;
  const frac = amount % base;
  const fracStr = frac.toString().padStart(Number(d), '0').slice(0, 6);
  return `${whole}.${fracStr}`;
}

/** Keep positions >= 0.000001 tokens (hide wei dust). */
function isMeaningful(amount, decimals) {
  const d = Number(decimals);
  const threshold = d >= 6 ? 10n ** BigInt(d - 6) : 1n;
  return amount >= threshold;
}

function line(id, venue, asset, amount, decimals, tag, usdMark, note) {
  return {
    id,
    venue,
    asset,
    amount: amount.toString(),
    human: toHuman(amount, decimals),
    decimals,
    tag,
    usdMark,
    note,
  };
}

async function walletBalances(label, wallet) {
  const tokens = [
    ['RSS', ADDR.RSS, 'internal-synthetic', 1.0, 'RSS @ $1.00 fixed oracle — synthetic'],
    ['USDC', ADDR.USDC, 'external-priced', 1.0, null],
    ['kUSD', ADDR.KUSD, 'internal-synthetic', 1.0, 'kUSD minted vs synthetic RSS — synthetic'],
    ['WETH', ADDR.WETH, 'external-priced', null, 'mark TBD'],
    ['cbBTC', ADDR.CBTC, 'external-priced', null, 'mark TBD'],
  ];
  const balCalls = tokens.map(([, token]) => ({
    to: token,
    data: SEL.balanceOf + encAddr(wallet),
  }));
  const results = await ethCallBatch(balCalls);
  const out = [];
  for (let i = 0; i < tokens.length; i++) {
    const [asset, token, tag, usdMark, note] = tokens[i];
    const amount = results[i] ? decodeUint(results[i]) : 0n;
    if (amount === 0n) continue;
    const decimals = await erc20Decimals(token);
    if (!isMeaningful(amount, decimals)) continue;
    out.push(
      line(
        `${label}-${asset.toLowerCase()}`,
        label,
        asset,
        amount,
        decimals,
        tag,
        usdMark,
        note,
      ),
    );
  }
  return out;
}

function sharesToAssets(shares, totalShares, totalAssets) {
  if (totalShares === 0n) return 0n;
  return (shares * totalAssets) / totalShares;
}

async function morphoBook(label, marketId, loanAsset, loanDec) {
  const [pos, mkt] = await Promise.all([
    morphoPosition(marketId, ADDR.HOT),
    morphoMarket(marketId),
  ]);
  if (!pos || !mkt) return { assets: [], debts: [], util: null, hfRaw: null };

  const collDec = await erc20Decimals(ADDR.RSS);
  const supplyAssets = sharesToAssets(pos.supplyShares, mkt.totalSupplyShares, mkt.totalSupplyAssets);
  const borrowAssets = sharesToAssets(pos.borrowShares, mkt.totalBorrowShares, mkt.totalBorrowAssets);

  const assets = [];
  const debts = [];

  if (pos.collateral > 0n) {
    assets.push(
      line(
        `${label}-coll-rss`,
        `morpho:${label}`,
        'RSS',
        pos.collateral,
        collDec,
        'internal-synthetic',
        1.0,
        'Morpho collateral RSS @ $1 synthetic',
      ),
    );
  }
  if (supplyAssets > 0n) {
    assets.push(
      line(
        `${label}-supply-${loanAsset}`,
        `morpho:${label}`,
        loanAsset,
        supplyAssets,
        loanDec,
        loanAsset === 'USDC' ? 'external-priced' : 'external-priced',
        loanAsset === 'USDC' ? 1.0 : null,
        'Morpho supply (loan side)',
      ),
    );
  }
  if (borrowAssets > 0n) {
    debts.push({
      id: `${label}-borrow-${loanAsset}`,
      venue: `morpho:${label}`,
      asset: loanAsset,
      amount: borrowAssets.toString(),
      human: toHuman(borrowAssets, loanDec),
      decimals: loanDec,
      tag: 'external-priced',
      usdMark: loanAsset === 'USDC' ? 1.0 : null,
      hfRaw: null,
      note: 'Morpho borrow',
    });
  }

  const util =
    mkt.totalSupplyAssets === 0n
      ? 0
      : Number(mkt.totalBorrowAssets) / Number(mkt.totalSupplyAssets);

  // HF approximation: collateral@$1 / borrow@unknown — only meaningful for USDC borrow
  let hfRaw = null;
  if (borrowAssets > 0n && loanAsset === 'USDC') {
    const collUsd = Number(pos.collateral) / 1e18;
    const debtUsd = Number(borrowAssets) / 1e6;
    hfRaw = debtUsd > 0 ? collUsd / debtUsd : null;
  }

  return { assets, debts, util, hfRaw, market: mkt };
}

/**
 * Full treasury snapshot for Phase 1 dashboard / CLI.
 */
export async function buildSnapshot() {
  const policy = loadPolicy();
  const oracle = await collectOracles();

  const wallets = [
    ['hot', ADDR.HOT],
    ['landing', ADDR.LANDING],
    ['desk', ADDR.DESK],
    ['multi', ADDR.MULTI],
    ['otc', ADDR.OTC_ETH],
    ['pcv', ADDR.PCV],
    ['lbp', ADDR.LBP],
  ];

  /** @type {any[]} */
  const assets = [];
  /** @type {any[]} */
  const debts = [];

  for (const [label, addr] of wallets) {
    assets.push(...(await walletBalances(label, addr)));
  }

  // Vaults
  const yRssAssets = await erc4626TotalAssets(ADDR.YRSS);
  const v2Assets = await erc4626TotalAssets(ADDR.VAULT_V2);
  if (yRssAssets != null && isMeaningful(yRssAssets, 18)) {
    assets.push(
      line(
        'yrss-tvl',
        'yrss-metamorpho-v1',
        'RSS',
        yRssAssets,
        18,
        'internal-synthetic',
        1.0,
        'yRSS MetaMorpho V1 TVL — not Vault V2',
      ),
    );
  }
  if (v2Assets != null && isMeaningful(v2Assets, 18)) {
    assets.push(
      line(
        'vault-v2-tvl',
        'high-treasury-vault-v2',
        'RSS',
        v2Assets,
        18,
        'internal-synthetic',
        1.0,
        'Private Meta Vault V2 totalAssets',
      ),
    );
  }

  // CDP / ZkAdvance kUSD outstanding (kUSD is 6 decimals)
  const kusdDec = await erc20Decimals(ADDR.KUSD);
  const kusdOnAdvance = await erc20Balance(ADDR.KUSD, ADDR.ZK_ADVANCE);
  if (isMeaningful(kusdOnAdvance, kusdDec)) {
    assets.push(
      line(
        'zk-advance-kusd',
        'zk-advance',
        'kUSD',
        kusdOnAdvance,
        kusdDec,
        'internal-synthetic',
        1.0,
        'kUSD sitting in ZkAdvance — synthetic inventory',
      ),
    );
  }

  // warm decimals once
  const usdcDec = await erc20Decimals(ADDR.USDC);
  const wethDec = await erc20Decimals(ADDR.WETH);
  const cbtcDec = await erc20Decimals(ADDR.CBTC);
  await erc20Decimals(ADDR.RSS);
  await erc20Decimals(ADDR.KUSD);

  // Morpho books — sequential to avoid RPC rate limits
  const books = [];
  for (const row of [
    ['rss-usdc', MARKETS.RSS_USDC, 'USDC', usdcDec],
    ['rss-weth', MARKETS.RSS_WETH, 'WETH', wethDec],
    ['rss-cbbtc', MARKETS.RSS_CBTC, 'cbBTC', cbtcDec],
  ]) {
    books.push(await morphoBook(...row));
  }

  for (const b of books) {
    assets.push(...b.assets);
    debts.push(...b.debts);
  }

  const penalty = await forceDeallocatePenalty(ADDR.VAULT_V2_ADAPTER, ADDR.VAULT_V2);
  const proven = await isZkProven(ADDR.HOT);

  // Totals — NEVER blend synthetic into external solvency
  let syntheticUsd = 0;
  let externalUsd = 0;
  for (const a of assets) {
    if (a.usdMark == null) continue;
    const human = Number(a.human);
    if (Number.isNaN(human)) continue;
    const usd = human * a.usdMark;
    if (a.tag === 'internal-synthetic') syntheticUsd += usd;
    else externalUsd += usd;
  }

  let externalDebtUsd = 0;
  for (const d of debts) {
    if (d.usdMark == null) continue;
    const human = Number(d.human);
    if (Number.isNaN(human)) continue;
    externalDebtUsd += human * d.usdMark;
  }

  const circularCap = policy.max_circular_exposure ?? 0;
  const flags = {
    zkProven: proven,
    forceDeallocatePenaltyWad: penalty != null ? penalty.toString() : null,
    forceDeallocatePenaltyOk:
      penalty != null && penalty >= BigInt(policy.force_deallocate_penalty_min_wad || '0'),
    anyOracleStale: oracle.anyExternalStale,
    circularExposureCap: circularCap,
    note:
      'Solvency reporting: externalNetUsd excludes internal-synthetic (RSS/kUSD@$1). Do not blend.',
  };

  return {
    asOf: new Date().toISOString(),
    assets,
    debts,
    totals: {
      syntheticMarkedUsd: Math.round(syntheticUsd * 100) / 100,
      externalMarkedUsd: Math.round(externalUsd * 100) / 100,
      externalDebtUsd: Math.round(externalDebtUsd * 100) / 100,
      externalNetUsd: Math.round((externalUsd - externalDebtUsd) * 100) / 100,
      morphoUtilization: {
        'rss-usdc': books[0].util,
        'rss-weth': books[1].util,
        'rss-cbbtc': books[2].util,
      },
    },
    oracle,
    flags,
    policy: {
      min_hf_raw: policy.min_hf_raw,
      max_circular_exposure: policy.max_circular_exposure,
      internal_synthetic_assets: policy.internal_synthetic_assets,
    },
  };
}

export { isInternalSyntheticAsset, loadPolicy };
