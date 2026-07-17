
/**
 * Open rescue desk — 5% Crown fee. Standing policy. No King hand-invites.
 * Stage A: auto-tag near-liq whales as `pipeline` (does NOT block hostile strikes).
 * Stage B (later): when a rescue actually executes, charge 5% and promote to active.
 */
import { db, logEvent } from "./db";

const ENABLED = (process.env.RESCUE_OPEN_ENROLL || "1") === "1";
const FEE = parseFloat(process.env.RESCUE_FEE_PCT || "0.05");
const MIN_DEBT = parseFloat(process.env.RESCUE_AUTO_MIN_DEBT_USD || "5000");
const MAX_HF = parseFloat(process.env.RESCUE_AUTO_MAX_HF || "1.08");
const INTERVAL = parseInt(process.env.RESCUE_OPEN_INTERVAL_MS || "60000", 10);
const MAX_PER_CYCLE = parseInt(process.env.RESCUE_OPEN_MAX_PER_CYCLE || "25", 10);

type Cand = {
  user: string;
  health_factor: number;
  debt_value_usd: number;
  protocol: string;
  collateral_symbol?: string;
  debt_symbol?: string;
};

export function runOpenEnrollCycle(): number {
  if (!ENABLED) return 0;
  const rows = db.prepare(`
    SELECT user, health_factor, debt_value_usd, protocol, collateral_symbol, debt_symbol
    FROM potential_targets
    WHERE health_factor > 1.0 AND health_factor <= ?
      AND debt_value_usd >= ?
      AND lower(user) NOT IN (
        SELECT lower(user) FROM rescue_clients WHERE status IN ('active','pipeline')
      )
    ORDER BY debt_value_usd DESC
    LIMIT ?
  `).all(MAX_HF, MIN_DEBT, MAX_PER_CYCLE) as Cand[];

  let n = 0;
  const upsert = db.prepare(`
    INSERT INTO rescue_clients
      (user, label, contact, fee_pct, hf_warn, hf_critical, protocol, market_id,
       collateral_symbol, debt_symbol, status, enrolled_at, updated_at, notes)
    VALUES (?, ?, NULL, ?, 1.05, 1.02, ?, NULL, ?, ?, 'pipeline', unixepoch(), unixepoch(), ?)
    ON CONFLICT(user) DO UPDATE SET
      fee_pct=excluded.fee_pct,
      protocol=excluded.protocol,
      collateral_symbol=excluded.collateral_symbol,
      debt_symbol=excluded.debt_symbol,
      status=CASE WHEN rescue_clients.status='active' THEN 'active' ELSE 'pipeline' END,
      updated_at=unixepoch(),
      notes=excluded.notes
  `);

  for (const r of rows) {
    try {
      const user = r.user.toLowerCase();
      upsert.run(
        user,
        `open ${r.protocol}`,
        FEE,
        r.protocol || "morpho",
        r.collateral_symbol ?? null,
        r.debt_symbol ?? null,
        `pipeline hf=${r.health_factor} debt=${r.debt_value_usd}`
      );
      const client = db.prepare("SELECT id FROM rescue_clients WHERE user=?").get(user) as { id: number };
      db.prepare(`
        INSERT INTO rescue_events (client_id, user, event_type, health_factor, debt_usd, detail, fee_usd, ts)
        VALUES (?, ?, 'pipeline_tagged', ?, ?, ?, 0, unixepoch())
      `).run(client.id, user, r.health_factor, r.debt_value_usd, `fee=${FEE}`);
      n++;
      console.log(`[rescue-open] pipeline ${user.slice(0,12)} debt=$${Math.round(r.debt_value_usd)} hf=${r.health_factor.toFixed(4)} fee=${(FEE*100).toFixed(0)}%`);
    } catch (e: any) {
      console.error(`[rescue-open] fail ${r.user.slice(0,12)}:`, e?.message || e);
    }
  }
  if (n > 0) logEvent("rescue", "open_pipeline_cycle", `tagged=${n} fee=${FEE}`);
  return n;
}

export async function runOpenEnrollLoop(intervalMs = INTERVAL): Promise<void> {
  console.log(`[rescue-open] LIVE fee=${(FEE*100).toFixed(0)}% pipeline-only (strikes NOT blocked) minDebt=$${MIN_DEBT} maxHF=${MAX_HF}`);
  try { runOpenEnrollCycle(); } catch (e: any) { console.error("[rescue-open]", e.message); }
  while (true) {
    await new Promise((r) => setTimeout(r, intervalMs));
    try { runOpenEnrollCycle(); } catch (e: any) { console.error("[rescue-open]", e.message); }
  }
}
