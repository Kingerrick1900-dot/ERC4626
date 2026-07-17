
import { db, logEvent } from "./db";

const INTERVAL_MS = parseInt(process.env.RESCUE_MONITOR_INTERVAL_MS || "30000", 10);
const DEFAULT_FEE = parseFloat(process.env.RESCUE_FEE_PCT || "0.07");
const DEDUPE_SEC = parseInt(process.env.RESCUE_ALERT_DEDUPE_SEC || "3600", 10);

type RescueClient = {
  id: number;
  user: string;
  label: string | null;
  contact: string | null;
  fee_pct: number;
  hf_warn: number;
  hf_critical: number;
  protocol: string | null;
  status: string;
};

type PositionSnap = {
  health_factor: number;
  debt_value_usd: number;
  collateral_value_usd: number;
  collateral_symbol: string;
  debt_symbol: string;
  protocol: string;
};

function latestPosition(user: string, protocol?: string | null): PositionSnap | null {
  const params: any[] = [user.toLowerCase()];
  let protoClause = "";
  if (protocol) {
    protoClause = " AND protocol = ?";
    params.push(protocol);
  }
  const row = db.prepare(`
    SELECT health_factor, debt_value_usd, collateral_value_usd,
           collateral_symbol, debt_symbol, protocol
    FROM scanner_records
    WHERE lower(user) = ?${protoClause}
    ORDER BY timestamp DESC, scanned_at DESC
    LIMIT 1
  `).get(...params) as PositionSnap | undefined;
  if (row) return row;

  const pt = db.prepare(`
    SELECT health_factor, debt_value_usd, collateral_value_usd,
           collateral_symbol, debt_symbol, protocol
    FROM potential_targets
    WHERE lower(user) = ?${protoClause}
    ORDER BY updated_at DESC
    LIMIT 1
  `).get(...params) as PositionSnap | undefined;
  return pt ?? null;
}

function recentEvent(clientId: number, eventType: string): boolean {
  const row = db.prepare(`
    SELECT 1 FROM rescue_events
    WHERE client_id = ? AND event_type = ?
      AND ts >= unixepoch() - ?
    LIMIT 1
  `).get(clientId, eventType, DEDUPE_SEC);
  return !!row;
}

function logRescueEvent(
  client: RescueClient,
  eventType: string,
  pos: PositionSnap | null,
  detail?: string,
  feeUsd = 0
) {
  db.prepare(`
    INSERT INTO rescue_events
      (client_id, user, event_type, health_factor, debt_usd, collateral_usd, detail, fee_usd, ts)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, unixepoch())
  `).run(
    client.id,
    client.user,
    eventType,
    pos?.health_factor ?? null,
    pos?.debt_value_usd ?? null,
    pos?.collateral_value_usd ?? null,
    detail ?? null,
    feeUsd
  );
  logEvent("rescue", eventType, `user=${client.user.slice(0, 12)} hf=${pos?.health_factor?.toFixed(4) ?? "n/a"} ${detail ?? ""}`.trim());
}

function classifyAlert(client: RescueClient, hf: number): string | null {
  if (hf < 1.0) return "hf_liquidatable";
  if (hf < client.hf_critical) return "hf_critical";
  if (hf < client.hf_warn) return "hf_warn";
  return null;
}

export function runRescueMonitor(): void {
  const clients = db.prepare(`
    SELECT id, user, label, contact, fee_pct, hf_warn, hf_critical, protocol, status
    FROM rescue_clients WHERE status = 'active'
  `).all() as RescueClient[];

  if (!clients.length) return;

  let alerts = 0;
  for (const client of clients) {
    const pos = latestPosition(client.user, client.protocol);
    if (!pos) continue;

    const hf = pos.health_factor;
    const alert = classifyAlert(client, hf);
    if (alert && !recentEvent(client.id, alert)) {
      const gap = ((hf - 1) / hf * 100).toFixed(2);
      const detail = `${pos.collateral_symbol}/${pos.debt_symbol} gap=${gap}% debt=$${Math.round(pos.debt_value_usd).toLocaleString()}`;
      logRescueEvent(client, alert, pos, detail);
      console.log(`[rescue] ALERT ${alert} ${client.label || client.user.slice(0, 10)} HF=${hf.toFixed(4)} ${detail}`);
      alerts++;
    }

    // Fee accrual when HF recovers above warn after prior critical/liquidatable event
    if (hf >= client.hf_warn) {
      const hadStress = db.prepare(`
        SELECT health_factor, debt_usd FROM rescue_events
        WHERE client_id = ? AND event_type IN ('hf_critical','hf_liquidatable')
        ORDER BY ts DESC LIMIT 1
      `).get(client.id) as { health_factor: number; debt_usd: number } | undefined;
      const alreadyPaid = db.prepare(`
        SELECT 1 FROM rescue_events
        WHERE client_id = ? AND event_type = 'fee_accrued'
          AND ts >= unixepoch() - ?
      `).get(client.id, DEDUPE_SEC * 24);
      if (hadStress && !alreadyPaid && pos.debt_value_usd > 0) {
        const feePct = client.fee_pct || DEFAULT_FEE;
        const feeUsd = pos.debt_value_usd * feePct;
        logRescueEvent(client, "fee_accrued", pos, `performance_fee=${(feePct * 100).toFixed(1)}%`, feeUsd);
        console.log(`[rescue] FEE $${feeUsd.toFixed(0)} accrued for ${client.label || client.user.slice(0, 10)}`);
      }
    }

    db.prepare("UPDATE rescue_clients SET updated_at=unixepoch() WHERE id=?").run(client.id);
  }

  if (alerts > 0) {
    logEvent("rescue", "monitor_cycle", `clients=${clients.length} alerts=${alerts}`);
  }
}

export async function runRescueMonitorLoop(intervalMs = INTERVAL_MS): Promise<void> {
  console.log(`[rescue] monitor live | interval=${intervalMs}ms fee=${(DEFAULT_FEE * 100).toFixed(1)}%`);
  while (true) {
    try { runRescueMonitor(); } catch (e: any) {
      console.error("[rescue] monitor error:", e.message);
    }
    await new Promise(r => setTimeout(r, intervalMs));
  }
}
