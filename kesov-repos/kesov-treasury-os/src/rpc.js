'use strict';

import { ADDR, rpcUrl } from './config.js';

function pad32(hex) {
  return String(hex).replace(/^0x/i, '').toLowerCase().padStart(64, '0');
}

function encAddr(a) {
  return pad32(a);
}

function encUint(n) {
  const v = typeof n === 'bigint' ? n : BigInt(n);
  return v.toString(16).padStart(64, '0');
}

/** keccak256 first 4 bytes — Foundry-verified selectors */
export const SEL = {
  balanceOf: '0x70a08231',
  decimals: '0x313ce567',
  totalSupply: '0x18160ddd',
  totalAssets: '0x01e1d114',
  market: '0x5c60e39a',
  position: '0x93c52062',
  isProven: '0xca5b4778',
  forceDeallocatePenaltyAddr: '0x99e99183',
  forceDeallocatePenalty: '0x27b79339',
  price: '0xa035b1fe',
};

const decimalsCache = new Map();
let rpcSeq = 1;
let lastCallAt = 0;
const MIN_GAP_MS = 40;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function throttle() {
  const now = Date.now();
  const wait = MIN_GAP_MS - (now - lastCallAt);
  if (wait > 0) await sleep(wait);
  lastCallAt = Date.now();
}

function isRateLimit(err) {
  const s = String(err?.message || err);
  return /rate limit|429|-32016|too many/i.test(s);
}

export async function ethCall(to, data, rpc = rpcUrl()) {
  let lastErr;
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      await throttle();
      const body = {
        jsonrpc: '2.0',
        id: rpcSeq++,
        method: 'eth_call',
        params: [{ to, data }, 'latest'],
      };
      const r = await fetch(rpc, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (r.status === 429) {
        await sleep(250 * 2 ** attempt);
        continue;
      }
      const j = await r.json();
      if (j.error) {
        if (isRateLimit(j.error)) {
          await sleep(250 * 2 ** attempt);
          continue;
        }
        throw new Error(JSON.stringify(j.error));
      }
      return j.result;
    } catch (e) {
      lastErr = e;
      if (isRateLimit(e) && attempt < 4) {
        await sleep(250 * 2 ** attempt);
        continue;
      }
      throw e;
    }
  }
  throw lastErr || new Error('eth_call failed');
}

/** Batch eth_call — falls back to serial on batch failure */
export async function ethCallBatch(calls, rpc = rpcUrl()) {
  if (!calls.length) return [];
  await throttle();
  const body = calls.map((c, i) => ({
    jsonrpc: '2.0',
    id: i + 1,
    method: 'eth_call',
    params: [{ to: c.to, data: c.data }, 'latest'],
  }));
  try {
    const r = await fetch(rpc, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (r.status === 429) throw new Error('rate limit');
    const j = await r.json();
    if (!Array.isArray(j)) throw new Error('batch not array');
    const byId = new Map(j.map((x) => [x.id, x]));
    return calls.map((_, i) => {
      const row = byId.get(i + 1);
      if (!row || row.error) return null;
      return row.result;
    });
  } catch {
    const out = [];
    for (const c of calls) {
      out.push(await ethCallOk(c.to, c.data, rpc));
    }
    return out;
  }
}

export async function ethCallOk(to, data, rpc = rpcUrl()) {
  try {
    return await ethCall(to, data, rpc);
  } catch {
    return null;
  }
}

export function decodeUint(hex) {
  if (!hex || hex === '0x') return 0n;
  return BigInt(hex);
}

export function decodeUintAt(hex, wordIndex) {
  const h = String(hex).replace(/^0x/i, '');
  const slice = h.slice(wordIndex * 64, wordIndex * 64 + 64);
  if (!slice) return 0n;
  return BigInt('0x' + slice);
}

export async function erc20Balance(token, account, rpc = rpcUrl()) {
  const data = SEL.balanceOf + encAddr(account);
  const out = await ethCall(token, data, rpc);
  return decodeUint(out);
}

export async function erc20Decimals(token, rpc = rpcUrl()) {
  const key = token.toLowerCase();
  if (decimalsCache.has(key)) return decimalsCache.get(key);
  const out = await ethCallOk(token, SEL.decimals, rpc);
  const d = out ? Number(decodeUint(out)) : 18;
  decimalsCache.set(key, d);
  return d;
}

export async function erc20TotalSupply(token, rpc = rpcUrl()) {
  const out = await ethCall(token, SEL.totalSupply, rpc);
  return decodeUint(out);
}

export async function erc4626TotalAssets(vault, rpc = rpcUrl()) {
  const out = await ethCallOk(vault, SEL.totalAssets, rpc);
  return out ? decodeUint(out) : null;
}

export async function morphoPosition(marketId, user, rpc = rpcUrl()) {
  const data = SEL.position + pad32(marketId) + encAddr(user);
  const out = await ethCallOk(ADDR.MORPHO, data, rpc);
  if (!out || out === '0x') return null;
  return {
    supplyShares: decodeUintAt(out, 0),
    borrowShares: decodeUintAt(out, 1),
    collateral: decodeUintAt(out, 2),
  };
}

export async function morphoMarket(marketId, rpc = rpcUrl()) {
  const data = SEL.market + pad32(marketId);
  const out = await ethCallOk(ADDR.MORPHO, data, rpc);
  if (!out || out === '0x') return null;
  return {
    totalSupplyAssets: decodeUintAt(out, 0),
    totalSupplyShares: decodeUintAt(out, 1),
    totalBorrowAssets: decodeUintAt(out, 2),
    totalBorrowShares: decodeUintAt(out, 3),
    lastUpdate: decodeUintAt(out, 4),
    fee: decodeUintAt(out, 5),
  };
}

/**
 * Morpho Vault V2: forceDeallocatePenalty(address adapter) on the vault.
 */
export async function forceDeallocatePenalty(adapter, vault, rpc = rpcUrl()) {
  let out = await ethCallOk(
    vault,
    SEL.forceDeallocatePenaltyAddr + encAddr(adapter),
    rpc,
  );
  if (!out || out === '0x') {
    out = await ethCallOk(
      adapter,
      SEL.forceDeallocatePenaltyAddr + encAddr(vault),
      rpc,
    );
  }
  if (!out || out === '0x') {
    out = await ethCallOk(adapter, SEL.forceDeallocatePenalty, rpc);
  }
  if (!out || out === '0x') return null;
  return decodeUint(out);
}

export async function isZkProven(account, rpc = rpcUrl()) {
  const data = SEL.isProven + encAddr(account);
  const out = await ethCallOk(ADDR.GATE, data, rpc);
  if (!out || out === '0x') return null;
  return decodeUint(out) !== 0n;
}

export async function oraclePrice(oracle, rpc = rpcUrl()) {
  const out = await ethCallOk(oracle, SEL.price, rpc);
  if (!out || out === '0x') return null;
  return decodeUint(out);
}

export { pad32, encAddr, encUint };
