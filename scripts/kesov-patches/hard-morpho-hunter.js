#!/usr/bin/env node
/**
 * hard-morpho-hunter — on-chain only (no Morpho API).
 * Reads morpho_state.json borrowers, computes live HF, arms only HF<1 with oracle coverage >= MIN_COV.
 * Skips known bad-debt symbols. Invokes find_and_fire when armed.
 */
"use strict";
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const { ethers } = require("/opt/kesov-kingdom/node_modules/ethers");
const Database = require("/opt/kesov-kingdom/node_modules/better-sqlite3");
require("/opt/kesov-kingdom/node_modules/dotenv").config({ path: "/opt/kesov-kingdom/.env" });

const ROOT = "/opt/kesov-kingdom";
const DB_PATH = path.join(ROOT, "kingdom.db");
const STATE_PATH = path.join(ROOT, "morpho_state.json");
const EVERY_MS = parseInt(process.env.HARD_HUNT_MS || "45000", 10);
const MIN_DEBT = parseFloat(process.env.HARD_HUNT_MIN_DEBT || "1000");
const MIN_COV = parseFloat(process.env.HARD_HUNT_MIN_COLL_COVERAGE || "0.85");
const BATCH = parseInt(process.env.HARD_HUNT_BATCH || "80", 10);
const BAD = new Set(["USR","RLP","wUSDM","cCOLL","ARGt","LCAP","BLO","BLC","TOSHI","doginme","MOCK","PERP","BondETH","wbCOIN"]);
const MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
const SCALE = ethers.BigNumber.from("10").pow(36);
const WAD = ethers.BigNumber.from("10").pow(18);

const MORPHO_ABI = [
  "function position(bytes32,address) view returns (uint256,uint128,uint128)",
  "function market(bytes32) view returns (uint128,uint128,uint128,uint128,uint128,uint128)",
  "function idToMarketParams(bytes32) view returns (address,address,address,address,uint256)",
];
const ORACLE_ABI = ["function price() view returns (uint256)"];
const ERC20_ABI = ["function decimals() view returns (uint8)", "function symbol() view returns (string)"];

function rpc() {
  const list = (process.env.RPC_URLS || process.env.RPC_URL || "").split(",").map(s => s.trim()).filter(Boolean);
  if (!list.length) throw new Error("RPC_URLS missing");
  return list[0];
}

function runFindAndFire() {
  return new Promise((resolve) => {
    const p = spawn("node", [path.join(ROOT, "find_and_fire.js")], { cwd: ROOT, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
    p.stdout.on("data", (d) => process.stdout.write(d));
    p.stderr.on("data", (d) => process.stderr.write(d));
    p.on("close", (code) => resolve(code));
  });
}

function seedRows(rows) {
  const db = new Database(DB_PATH);
  const upsertPt = db.prepare(`INSERT INTO potential_targets
      (user, collateral_asset, collateral_symbol, debt_asset, debt_symbol,
       collateral_value_usd, debt_value_usd, health_factor, risk_tier, priority_score,
       total_exposure_usd, updated_at, protocol, market_id)
    VALUES (?,?,?,?,?,?,?,?,'EXECUTE',999990,?,unixepoch(),'morpho',?)
    ON CONFLICT(user, collateral_asset, debt_asset) DO UPDATE SET
      health_factor=excluded.health_factor, debt_value_usd=excluded.debt_value_usd,
      collateral_value_usd=excluded.collateral_value_usd, collateral_symbol=excluded.collateral_symbol,
      debt_symbol=excluded.debt_symbol, risk_tier='EXECUTE', priority_score=999990,
      protocol='morpho', market_id=excluded.market_id, updated_at=unixepoch()`);
  const upsertQ = db.prepare(`INSERT INTO liquidation_queue
      (user, collateral_asset, collateral_symbol, debt_asset, debt_symbol,
       collateral_value_usd, debt_value_usd, debt_to_cover, net_profit_usd, gas_estimate,
       priority_score, status, created_at, protocol, market_id)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,'pending',unixepoch(),'morpho',?)
    ON CONFLICT(user, collateral_asset, debt_asset) DO UPDATE SET
      collateral_value_usd=excluded.collateral_value_usd, debt_value_usd=excluded.debt_value_usd,
      debt_to_cover=excluded.debt_to_cover, net_profit_usd=excluded.net_profit_usd,
      priority_score=excluded.priority_score, protocol='morpho', market_id=excluded.market_id,
      status=CASE
        WHEN liquidation_queue.status IN ('claimed','executing') THEN liquidation_queue.status
        WHEN liquidation_queue.status IN ('failed','executed','done') THEN liquidation_queue.status
        ELSE 'pending' END,
      failure_reason=CASE
        WHEN liquidation_queue.status IN ('failed','executed','done') THEN liquidation_queue.failure_reason
        ELSE NULL END,
      created_at=unixepoch()`);
  let n = 0;
  for (const r of rows) {
    upsertPt.run(r.user, r.ca, r.cs, r.da, r.ds, r.collUsd, r.debtUsd, r.hf, r.collUsd + r.debtUsd, r.mid);
    upsertQ.run(r.user, r.ca, r.cs, r.da, r.ds, r.collUsd, r.debtUsd, String(r.debtUsd * 0.5), r.debtUsd * 0.5 * 0.05, 600000, 999990, r.mid);
    n++;
    console.log(`[hard-hunt] ARMED hf=${r.hf.toFixed(4)} ${r.cs}/${r.ds} debt=$${Math.round(r.debtUsd)} coll=$${Math.round(r.collUsd)} ${r.user.slice(0,12)}`);
  }
  db.close();
  return n;
}

async function tick() {
  console.log(`\n[hard-hunt] ${new Date().toISOString()} on-chain Morpho HF scan…`);
  if (!fs.existsSync(STATE_PATH)) throw new Error("missing morpho_state.json");
  const state = JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
  const provider = new ethers.providers.StaticJsonRpcProvider(rpc(), { chainId: 8453, name: "base" });
  const morpho = new ethers.Contract(MORPHO, MORPHO_ABI, provider);

  // Flatten borrowers → prioritize near greys from DB too
  const pairs = [];
  for (const [mid, users] of Object.entries(state.borrowers || {})) {
    const m = (state.markets || {})[mid];
    if (!m) continue;
    const cs = m.collateralSymbol || "?";
    if (BAD.has(cs)) continue;
    for (const u of users) pairs.push({ mid, user: String(u).toLowerCase(), market: m });
  }
  // Also include potential_targets HF < 1.05 morpho
  try {
    const db = new Database(DB_PATH, { readonly: true });
    const extras = db.prepare(`SELECT user, market_id FROM potential_targets WHERE protocol='morpho' AND health_factor < 1.05 AND market_id IS NOT NULL`).all();
    db.close();
    for (const e of extras) {
      if (!pairs.find(p => p.user === e.user && p.mid === e.market_id)) {
        const m = (state.markets || {})[e.market_id];
        if (m && !BAD.has(m.collateralSymbol || "")) pairs.push({ mid: e.market_id, user: e.user, market: m });
      }
    }
  } catch (_) {}

  console.log(`[hard-hunt] candidates=${pairs.length}`);
  // Sample rotating window each tick so we cover universe over time
  const offset = Math.floor(Date.now() / EVERY_MS) % Math.max(1, pairs.length);
  const window = [];
  for (let i = 0; i < Math.min(BATCH, pairs.length); i++) window.push(pairs[(offset + i) % pairs.length]);

  const armed = [];
  for (const p of window) {
    try {
      const params = await morpho.idToMarketParams(p.mid);
      const loan = params[0], col = params[1], oracle = params[2], lltv = params[4];
      const pos = await morpho.position(p.mid, ethers.utils.getAddress(p.user));
      const mk = await morpho.market(p.mid);
      const borrowShares = ethers.BigNumber.from(pos[1].toString());
      const collateral = ethers.BigNumber.from(pos[2].toString());
      if (borrowShares.isZero() || collateral.isZero()) continue;
      const totalBorrowAssets = ethers.BigNumber.from(mk[2].toString());
      const totalBorrowShares = ethers.BigNumber.from(mk[3].toString());
      const borrowed = totalBorrowShares.isZero() ? ethers.BigNumber.from(0) : borrowShares.mul(totalBorrowAssets).div(totalBorrowShares);
      const price = await new ethers.Contract(oracle, ORACLE_ABI, provider).price();
      const colInLoan = collateral.mul(price).div(SCALE);
      const maxBorrow = colInLoan.mul(lltv).div(WAD);
      if (borrowed.isZero()) continue;
      const hf = parseFloat(maxBorrow.toString()) / parseFloat(borrowed.toString());
      if (!(hf < 1.0)) continue;

      const loanDec = p.market.loanDecimals ?? 6;
      const debtUsd = parseFloat(ethers.utils.formatUnits(borrowed, loanDec)); // USDC-like approx
      const collUsd = parseFloat(ethers.utils.formatUnits(colInLoan, loanDec));
      if (debtUsd < MIN_DEBT) continue;
      if (collUsd / debtUsd < MIN_COV) {
        console.log(`[hard-hunt] SKIP thin ${p.market.collateralSymbol}/${p.market.loanSymbol} cov=${(collUsd/debtUsd).toFixed(3)} debt=$${Math.round(debtUsd)}`);
        continue;
      }
      armed.push({
        user: p.user, mid: p.mid, hf, debtUsd, collUsd,
        ca: col, da: loan,
        cs: p.market.collateralSymbol || "COL",
        ds: p.market.loanSymbol || "DEBT",
      });
    } catch (e) {
      // skip individual RPC failures
    }
  }

  const n = seedRows(armed);
  console.log(`[hard-hunt] armed=${n}`);
  if (n > 0) await runFindAndFire();
  else console.log("[hard-hunt] no on-chain underwater with coverage — idle");
}

(async () => {
  console.log(`[hard-hunt] ONCHAIN LIVE minDebt=$${MIN_DEBT} minCoverage=${MIN_COV} batch=${BATCH} interval=${EVERY_MS}ms`);
  for (;;) {
    try { await tick(); } catch (e) { console.error("[hard-hunt] error", e.message || e); }
    await new Promise((r) => setTimeout(r, EVERY_MS));
  }
})();
