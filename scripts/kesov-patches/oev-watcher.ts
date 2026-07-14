// oev-watcher.ts — Oracle Extractable Value cross-chain watcher
// Monitors Chainlink on Optimism (19-27s ahead of Base) and pre-positions liquidations
import { ethers } from "ethers";
import Database from "better-sqlite3";
import { logEvent } from "./db";
import { estimateNetProfitUsd, OEV_PRIORITY_SCORE, sanitizeDebtUsd } from "./sentinels";

const OPT_RPC       = process.env.OPT_RPC_URL || "https://mainnet.optimism.io";
const DB_PATH       = process.env.DB_PATH || "/opt/kesov-kingdom/kingdom.db";
const POLL_MS       = parseInt(process.env.OEV_POLL_MS || "3000", 10);
const USDE_SIEGE = process.env.USDE_SIEGE_MODE === "true";
const OEV_THRESHOLD = parseFloat(process.env.OEV_HF_THRESHOLD || "1.015");

// Chainlink aggregator proxy addresses on Optimism mainnet (8 decimals)
const FEEDS = {
  BTC: "0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593",
  ETH: "0x13e3Ee699D1909E989722E753853AE30b17e08c5",
} as const;

const BTC_COL   = new Set(["cbBTC","LBTC","wBTC","BTC","tBTC"]);
const ETH_COL   = new Set(["WETH","weETH","wstETH","cbETH","ETH","rETH"]);
const STABLE_DEBT = new Set(["USDC","USDT","DAI","GHO","EURC","USDbC","cUSDC","USDS"]);

const AGG_ABI = [
  "function latestRoundData() view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
];

interface FeedState { roundId: bigint; price: number; }
const state: Record<"BTC"|"ETH", FeedState|null> = { BTC: null, ETH: null };

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

function toPrice(raw: ethers.BigNumber): number {
  return parseFloat(ethers.utils.formatUnits(raw, 8));
}

function getProjectables(db: Database.Database) {
  const sql = `
    SELECT user, collateral_symbol, debt_symbol, collateral_asset, debt_asset,
           collateral_value_usd, debt_value_usd, health_factor, debt_to_cover,
           COALESCE(liquidation_bonus, 1.05) AS liquidation_bonus, protocol, market_id
    FROM scanner_records
    WHERE health_factor BETWEEN 0.88 AND 1.12 AND debt_value_usd > 100
    UNION
    SELECT user, collateral_symbol, debt_symbol, collateral_asset, debt_asset,
           collateral_value_usd, debt_value_usd, health_factor,
           debt_value_usd * 0.5 AS debt_to_cover,
           1.05 AS liquidation_bonus, protocol, market_id
    FROM potential_targets
    WHERE health_factor BETWEEN 0.88 AND 1.12 AND debt_value_usd > 100
    ORDER BY health_factor ASC`;
  const rows = db.prepare(sql).all() as any[];
  if (!USDE_SIEGE) return rows;
  const minDebt = parseFloat(process.env.USDE_SIEGE_MIN_DEBT || "500000");
  return rows.filter((r: any) =>
    (r.collateral_symbol === "USDe" && r.debt_symbol === "USDC" && (r.debt_value_usd || 0) >= minDebt) ||
    (BTC_COL.has(r.collateral_symbol) && (r.debt_value_usd || 0) >= minDebt)
  );
}

function oevQueue(db: Database.Database, pos: any) {
  const debtUsd = sanitizeDebtUsd(pos.debt_value_usd) ?? 0;
  if (debtUsd <= 0) return;
  // Morpho backrun ONLY. Never arm Aave/other greys through OEV pre-queue.
  const protocol = (pos.protocol ?? "morpho").toLowerCase();
  if (protocol !== "morpho") return;
  if (!pos.market_id) return;
  const debtToCover = Number(pos.debt_to_cover) > 0 ? Number(pos.debt_to_cover) : debtUsd * 0.5;
  const bonus = Number(pos.liquidation_bonus) || 1.05;
  const profit = estimateNetProfitUsd(debtToCover, bonus, 0);
  if (profit === null) return;
  db.prepare(
    "INSERT INTO liquidation_queue" +
    " (user,collateral_asset,collateral_symbol,debt_asset,debt_symbol," +
    "  collateral_value_usd,debt_value_usd,debt_to_cover,net_profit_usd,gas_estimate,priority_score," +
    "  status,created_at,protocol,market_id,comet_address)" +
    " VALUES(?,?,?,?,?,?,?,?,?,?,?,'pending',unixepoch(),?,?,NULL)" +
    " ON CONFLICT(user,collateral_asset,debt_asset) DO UPDATE SET" +
    "  collateral_value_usd=excluded.collateral_value_usd," +
    "  debt_value_usd=excluded.debt_value_usd," +
    "  debt_to_cover=excluded.debt_to_cover," +
    "  net_profit_usd=excluded.net_profit_usd," +
    "  priority_score=excluded.priority_score," +
    "  protocol=excluded.protocol," +
    "  market_id=excluded.market_id," +
    // Never resurrect failed/expired/executed. Never yank claimed/executing mid-flight.
    "  status=CASE" +
    "    WHEN liquidation_queue.status IN ('claimed','executing') THEN liquidation_queue.status" +
    "    WHEN liquidation_queue.status IN ('failed','executed','done') THEN liquidation_queue.status" +
    "    ELSE 'pending' END," +
    "  failure_reason=CASE" +
    "    WHEN liquidation_queue.status IN ('failed','executed','done') THEN liquidation_queue.failure_reason" +
    "    ELSE NULL END," +
    "  created_at=unixepoch()"
  ).run(
    pos.user, pos.collateral_asset, pos.collateral_symbol,
    pos.debt_asset, pos.debt_symbol,
    pos.collateral_value_usd, debtUsd, String(debtToCover),
    profit, 600000, OEV_PRIORITY_SCORE,
    protocol, pos.market_id ?? null
  );
}

async function pollFeed(
  feed: "BTC"|"ETH",
  agg: ethers.Contract,
  db: Database.Database,
  colSet: Set<string>
) {
  try {
    const [roundId, answer] = await agg.latestRoundData();
    const price = toPrice(answer);
    const prev  = state[feed];

    if (!prev) {
      state[feed] = { roundId: roundId.toBigInt(), price };
      console.log("[oev] " + feed + "/USD init — $" + price.toFixed(2) + " round=" + roundId.toString() + " (Optimism)");
      return;
    }

    const newRound = roundId.toBigInt();
    if (newRound <= prev.roundId) return;

    const ratio = price / prev.price;
    const pct   = ((ratio - 1) * 100).toFixed(3);
    state[feed] = { roundId: newRound, price };

    console.log("[oev] OPTIMISM " + feed + "/USD ROUND " + newRound + " -> $" + price.toFixed(2) + " (" + pct + "%) — Base oracle incoming ~19-27s");
    logEvent("oev", "opt_" + feed.toLowerCase() + "_round", "price=" + price.toFixed(2) + " ratio=" + ratio.toFixed(6));

    if (Math.abs(ratio - 1) < 0.0003) return;

    const positions = getProjectables(db);
    let queued = 0;

    for (const pos of positions) {
      if (!colSet.has(pos.collateral_symbol)) continue;
      if (!STABLE_DEBT.has(pos.debt_symbol))  continue;
      const projHF = pos.health_factor * ratio;
      if (projHF >= OEV_THRESHOLD) continue;

      oevQueue(db, pos);
      queued++;
      console.log(
        "[oev] PRE-QUEUE " + pos.collateral_symbol + "->" + pos.debt_symbol +
        " user=" + pos.user.slice(0, 10) +
        " HF=" + pos.health_factor.toFixed(4) + "->" + projHF.toFixed(4) +
        " debt=$" + Math.round(pos.debt_value_usd).toLocaleString()
      );
    }

    if (queued > 0) {
      console.log("[oev] " + queued + " positions PRE-QUEUED on " + feed + " signal — executor firing before Base oracle lands");
      logEvent("oev", "batch_prequeued", "feed=" + feed + " count=" + queued + " price=" + price.toFixed(2));
    } else {
      console.log("[oev] " + feed + " round " + newRound + " — no positions crossed threshold");
    }

  } catch (err: any) {
    if (err.message && !err.message.includes("noNetwork")) {
      console.error("[oev] " + feed + " poll error: " + err.message.slice(0, 80));
    }
  }
}

export async function runOEVWatcher() {
  console.log("[oev] OEV Cross-Chain Oracle Watcher starting");
  console.log("[oev] Optimism leads Base by 19-27 seconds");
  console.log("[oev] RPC=" + OPT_RPC + " poll=" + POLL_MS + "ms threshold=HF<" + OEV_THRESHOLD);

  const provider = new ethers.providers.StaticJsonRpcProvider(OPT_RPC, 10);
  const btcAgg   = new ethers.Contract(FEEDS.BTC, AGG_ABI, provider);
  const ethAgg   = new ethers.Contract(FEEDS.ETH, AGG_ABI, provider);
  const db       = new Database(DB_PATH);

  try {
    const block = await provider.getBlockNumber();
    console.log("[oev] Optimism connected — block " + block);
  } catch (e: any) {
    console.error("[oev] Optimism RPC failed: " + e.message + " — continuing anyway");
  }

  while (true) {
    await Promise.all([
      pollFeed("BTC", btcAgg, db, BTC_COL),
      pollFeed("ETH", ethAgg, db, ETH_COL),
    ]);
    await sleep(POLL_MS);
  }
}
