#!/usr/bin/env python3
"""Phase 2 — Rescue Desk: enrollment, queue exclusion, HF monitor, intel API."""
from __future__ import annotations

import datetime
import paramiko
import textwrap

HOST, USER, PASSWORD = "5.78.226.227", "root", "rC9jmJmhvdCh"
ROOT = "/opt/kesov-kingdom"

RESCUE_MONITOR_TS = textwrap.dedent(r'''
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
''')

DB_RESCUE_APPEND = textwrap.dedent(r'''

// ── Rescue Desk schema ─────────────────────────────────────────────────────
db.exec(`
CREATE TABLE IF NOT EXISTS rescue_clients (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  user             TEXT NOT NULL UNIQUE,
  label            TEXT,
  contact          TEXT,
  fee_pct          REAL NOT NULL DEFAULT 0.07,
  hf_warn          REAL NOT NULL DEFAULT 1.05,
  hf_critical      REAL NOT NULL DEFAULT 1.02,
  protocol         TEXT DEFAULT 'morpho',
  market_id        TEXT,
  collateral_symbol TEXT,
  debt_symbol      TEXT,
  status           TEXT NOT NULL DEFAULT 'active',
  enrolled_at      INTEGER DEFAULT (unixepoch()),
  updated_at       INTEGER DEFAULT (unixepoch()),
  notes            TEXT
);
CREATE TABLE IF NOT EXISTS rescue_events (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id        INTEGER,
  user             TEXT NOT NULL,
  event_type       TEXT NOT NULL,
  health_factor    REAL,
  debt_usd         REAL,
  collateral_usd   REAL,
  detail           TEXT,
  fee_usd          REAL DEFAULT 0,
  ts               INTEGER DEFAULT (unixepoch())
);
CREATE INDEX IF NOT EXISTS idx_rescue_clients_user ON rescue_clients(user);
CREATE INDEX IF NOT EXISTS idx_rescue_events_ts ON rescue_events(ts DESC);
`);

export function isRescueClient(user: string): boolean {
  const row = db.prepare(
    "SELECT 1 FROM rescue_clients WHERE lower(user)=lower(?) AND status='active' LIMIT 1"
  ).get(user);
  return !!row;
}

export function purgeRescueFromQueue(user: string): number {
  const res = db.prepare(`
    UPDATE liquidation_queue
    SET status='failed', failure_reason='rescue_client_excluded'
    WHERE lower(user)=lower(?)
      AND status IN ('pending','claimed','executing')
  `).run(user);
  return res.changes;
}

export function enrollRescueClient(r: {
  user: string; label?: string; contact?: string;
  fee_pct?: number; hf_warn?: number; hf_critical?: number;
  protocol?: string; market_id?: string;
  collateral_symbol?: string; debt_symbol?: string; notes?: string;
}) {
  const user = r.user.toLowerCase();
  db.prepare(`
    INSERT INTO rescue_clients
      (user, label, contact, fee_pct, hf_warn, hf_critical, protocol, market_id,
       collateral_symbol, debt_symbol, status, enrolled_at, updated_at, notes)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', unixepoch(), unixepoch(), ?)
    ON CONFLICT(user) DO UPDATE SET
      label=excluded.label,
      contact=excluded.contact,
      fee_pct=excluded.fee_pct,
      hf_warn=excluded.hf_warn,
      hf_critical=excluded.hf_critical,
      protocol=excluded.protocol,
      market_id=excluded.market_id,
      collateral_symbol=excluded.collateral_symbol,
      debt_symbol=excluded.debt_symbol,
      status='active',
      updated_at=unixepoch(),
      notes=excluded.notes
  `).run(
    user,
    r.label ?? null,
    r.contact ?? null,
    r.fee_pct ?? parseFloat(process.env.RESCUE_FEE_PCT || "0.07"),
    r.hf_warn ?? parseFloat(process.env.RESCUE_ALERT_HF_WARN || "1.05"),
    r.hf_critical ?? parseFloat(process.env.RESCUE_ALERT_HF_CRITICAL || "1.02"),
    r.protocol ?? "morpho",
    r.market_id ?? null,
    r.collateral_symbol ?? null,
    r.debt_symbol ?? null,
    r.notes ?? null
  );
  const changes = purgeRescueFromQueue(user);
  const client = db.prepare("SELECT id FROM rescue_clients WHERE user=?").get(user) as { id: number };
  db.prepare(`
    INSERT INTO rescue_events (client_id, user, event_type, detail, ts)
    VALUES (?, ?, 'enrolled', ?, unixepoch())
  `).run(client.id, user, `queue_purged=${changes}`);
  logEvent("rescue", "client_enrolled", `user=${user.slice(0, 12)} purged=${changes}`);
  return { user, queuePurged: changes };
}

export function removeRescueClient(user: string, reason = "removed") {
  const u = user.toLowerCase();
  const client = db.prepare("SELECT id FROM rescue_clients WHERE user=?").get(u) as { id: number } | undefined;
  db.prepare("UPDATE rescue_clients SET status='churned', updated_at=unixepoch() WHERE user=?").run(u);
  if (client) {
    db.prepare(`
      INSERT INTO rescue_events (client_id, user, event_type, detail, ts)
      VALUES (?, ?, 'removed', ?, unixepoch())
    `).run(client.id, u, reason);
  }
  logEvent("rescue", "client_removed", `user=${u.slice(0, 12)} reason=${reason}`);
}

export function getRescueClients(): any[] {
  return db.prepare("SELECT * FROM rescue_clients WHERE status != 'churned' ORDER BY enrolled_at DESC").all();
}

export function getRescueEvents(limit = 50): any[] {
  return db.prepare("SELECT * FROM rescue_events ORDER BY ts DESC LIMIT ?").all(limit);
}

export function getRescueStats(): any {
  const clients = (db.prepare("SELECT COUNT(*) n FROM rescue_clients WHERE status='active'").get() as any).n;
  const fees = (db.prepare("SELECT COALESCE(SUM(fee_usd),0) s FROM rescue_events WHERE event_type='fee_accrued'").get() as any).s;
  const alerts = (db.prepare(`
    SELECT COUNT(*) n FROM rescue_events
    WHERE event_type IN ('hf_warn','hf_critical','hf_liquidatable')
      AND ts >= unixepoch() - 86400
  `).get() as any).n;
  return { activeClients: clients, feesAccruedUsd: fees, alerts24h: alerts };
}
''')


def ssh_connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username=USER, password=PASSWORD, timeout=20, allow_agent=False, look_for_keys=False)
    return c


def run(client, cmd: str) -> str:
    _, stdout, stderr = client.exec_command(cmd, timeout=120)
    out = stdout.read().decode()
    err = stderr.read().decode()
    if err.strip():
        out += "\nSTDERR: " + err
    return out


def read_remote(client, path: str) -> str:
    return run(client, f"cat {path}")


def write_remote(client, path: str, content: str):
    import base64
    b64 = base64.b64encode(content.encode()).decode()
    run(client, f"python3 -c \"import base64; open('{path}','wb').write(base64.b64decode('{b64}'))\"")


def patch_file(client, path: str, old: str, new: str, label: str):
    content = read_remote(client, path)
    if old not in content:
        raise RuntimeError(f"{label}: anchor not found in {path}")
    bak = f"{path}.bak-phase2-{int(datetime.datetime.now().timestamp())}"
    run(client, f"cp {path} {bak}")
    write_remote(client, path, content.replace(old, new, 1))
    print(f"  patched {label}")


def main():
    client = ssh_connect()
    ts = int(datetime.datetime.now().timestamp())

    print("=== backups ===")
    for f in ["db.ts", "intelligence.ts", "index.ts", "intel.ts"]:
        run(client, f"cp {ROOT}/src/{f} {ROOT}/src/{f}.bak-phase2-{ts}")

    print("=== rescue-monitor.ts ===")
    write_remote(client, f"{ROOT}/src/rescue-monitor.ts", RESCUE_MONITOR_TS)

    print("=== db.ts ===")
    db = read_remote(client, f"{ROOT}/src/db.ts")
    if "rescue_clients" not in db:
        db = db.rstrip() + "\n" + DB_RESCUE_APPEND + "\n"
        write_remote(client, f"{ROOT}/src/db.ts", db)
        print("  appended rescue schema + helpers")
    else:
        print("  rescue schema already present")

    # Exclude rescue clients from claimNextTarget
    patch_file(client, f"{ROOT}/src/db.ts",
        '    "(net_profit_usd IS NULL OR net_profit_usd < 9999990)",\n    "NOT (debt_value_usd <= 0 AND net_profit_usd >= 9999990)",',
        '    "(net_profit_usd IS NULL OR net_profit_usd < 9999990)",\n    "NOT (debt_value_usd <= 0 AND net_profit_usd >= 9999990)",\n    "NOT EXISTS (SELECT 1 FROM rescue_clients rc WHERE rc.status=\'active\' AND lower(rc.user)=lower(liquidation_queue.user))",',
        "claimNextTarget rescue exclusion")

    # Skip rescue clients in upsertLiquidationQueue
    patch_file(client, f"{ROOT}/src/db.ts",
        'export function upsertLiquidationQueue(r: {\n  user: string; collateral_asset: string; collateral_symbol: string;\n  debt_asset: string; debt_symbol: string; debt_to_cover: string;\n  collateral_value_usd: number; debt_value_usd?: number; net_profit_usd: number; gas_estimate: number; priority_score: number;\n  protocol?: string; market_id?: string; comet_address?: string;\n}) {\n  const debtUsd = hydrateDebtFromTargets',
        'export function upsertLiquidationQueue(r: {\n  user: string; collateral_asset: string; collateral_symbol: string;\n  debt_asset: string; debt_symbol: string; debt_to_cover: string;\n  collateral_value_usd: number; debt_value_usd?: number; net_profit_usd: number; gas_estimate: number; priority_score: number;\n  protocol?: string; market_id?: string; comet_address?: string;\n}) {\n  if (isRescueClient(r.user)) return;\n  const debtUsd = hydrateDebtFromTargets',
        "upsertLiquidationQueue rescue skip")

    print("=== intelligence.ts ===")
    patch_file(client, f"{ROOT}/src/intelligence.ts",
        'import { getAtRiskRecords, upsertPotentialTarget, upsertLiquidationQueue, cleanupStaleTiers, logEvent } from "./db";',
        'import { getAtRiskRecords, upsertPotentialTarget, upsertLiquidationQueue, cleanupStaleTiers, logEvent, isRescueClient } from "./db";',
        "intelligence import")
    patch_file(client, f"{ROOT}/src/intelligence.ts",
        '    // ── Skip known bad-debt (depegged collateral) — preflight always fails ──\n    if (BAD_DEBT_COLLATERAL.has(r.collateral_symbol as string)) continue;',
        '    // ── Rescue desk clients — never queue for liquidation ──\n    if (isRescueClient(r.user as string)) continue;\n    // ── Skip known bad-debt (depegged collateral) — preflight always fails ──\n    if (BAD_DEBT_COLLATERAL.has(r.collateral_symbol as string)) continue;',
        "intelligence rescue skip")

    print("=== index.ts ===")
    patch_file(client, f"{ROOT}/src/index.ts",
        'import { logEvent, cleanupInvalidQueueRows } from "./db";',
        'import { logEvent, cleanupInvalidQueueRows } from "./db";\nimport { runRescueMonitorLoop } from "./rescue-monitor";',
        "index import")
    patch_file(client, f"{ROOT}/src/index.ts",
        'runIntelligenceLoop(30_000);',
        'runIntelligenceLoop(30_000);\nrunRescueMonitorLoop(30_000);',
        "index rescue loop")

    print("=== intel.ts API ===")
    intel = read_remote(client, f"{ROOT}/src/intel.ts")

    if "function rwDb()" not in intel:
        intel = intel.replace(
            'function db() {\n  const Db = require("better-sqlite3");\n  return new Db(DB_PATH, { readonly: true, fileMustExist: true });\n}',
            'function db() {\n  const Db = require("better-sqlite3");\n  return new Db(DB_PATH, { readonly: true, fileMustExist: true });\n}\nfunction rwDb() {\n  const Db = require("better-sqlite3");\n  return new Db(DB_PATH);\n}'
        )

    if 'RESCUE_FEE_PCT' not in intel:
        intel = intel.replace(
            'const MIN_DEBT  = parseInt(process.env.MIN_DEBT_THRESHOLD || "90000", 10);',
            'const MIN_DEBT  = parseInt(process.env.MIN_DEBT_THRESHOLD || "90000", 10);\nconst RESCUE_FEE_PCT = parseFloat(process.env.RESCUE_FEE_PCT || "0.07");'
        )

    api_block = r'''
// ── API: Rescue Desk ───────────────────────────────────────────────────────
app.get("/api/rescue", (_req, res) => {
  try {
    const d = db();
    const clients = d.prepare(`
      SELECT rc.*,
             COALESCE(sr.health_factor, pt.health_factor) AS health_factor,
             COALESCE(sr.debt_value_usd, pt.debt_value_usd) AS debt_value_usd,
             COALESCE(sr.collateral_value_usd, pt.collateral_value_usd) AS collateral_value_usd,
             COALESCE(sr.collateral_symbol, rc.collateral_symbol, pt.collateral_symbol) AS live_collateral,
             COALESCE(sr.debt_symbol, rc.debt_symbol, pt.debt_symbol) AS live_debt
      FROM rescue_clients rc
      LEFT JOIN (
        SELECT user, health_factor, debt_value_usd, collateral_value_usd, collateral_symbol, debt_symbol
        FROM scanner_records
        WHERE rowid IN (SELECT MAX(rowid) FROM scanner_records GROUP BY user)
      ) sr ON lower(sr.user) = lower(rc.user)
      LEFT JOIN (
        SELECT user, health_factor, debt_value_usd, collateral_value_usd, collateral_symbol, debt_symbol
        FROM potential_targets
        WHERE rowid IN (SELECT MAX(rowid) FROM potential_targets GROUP BY user)
      ) pt ON lower(pt.user) = lower(rc.user)
      WHERE rc.status != 'churned'
      ORDER BY COALESCE(sr.health_factor, pt.health_factor, 99) ASC
    `).all();
    const stats = d.prepare(`
      SELECT
        (SELECT COUNT(*) FROM rescue_clients WHERE status='active') AS active_clients,
        (SELECT COALESCE(SUM(fee_usd),0) FROM rescue_events WHERE event_type='fee_accrued') AS fees_accrued,
        (SELECT COUNT(*) FROM rescue_events WHERE event_type IN ('hf_warn','hf_critical','hf_liquidatable') AND ts >= unixepoch()-86400) AS alerts_24h
    `).get();
    d.close();
    res.json({ ok: true, clients, stats, feePct: RESCUE_FEE_PCT, ts: Date.now() });
  } catch (e: any) { res.status(500).json({ ok: false, error: e.message }); }
});

app.get("/api/rescue/events", (req, res) => {
  try {
    const d = db();
    const limit = Math.min(parseInt(String(req.query.limit || "50"), 10) || 50, 200);
    const events = d.prepare("SELECT * FROM rescue_events ORDER BY ts DESC LIMIT ?").all(limit);
    d.close();
    res.json({ ok: true, events });
  } catch (e: any) { res.status(500).json({ ok: false, error: e.message }); }
});

app.post("/api/rescue/enroll", requireAuth, (req, res) => {
  try {
    const { user, label, contact, protocol, notes, fee_pct, hf_warn, hf_critical } = req.body || {};
    if (!user || typeof user !== "string" || user.length < 10)
      return res.json({ ok: false, error: "user address required" });
    const d = rwDb();
    const u = user.toLowerCase();
    d.prepare(`
      INSERT INTO rescue_clients
        (user, label, contact, fee_pct, hf_warn, hf_critical, protocol, status, enrolled_at, updated_at, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'active', unixepoch(), unixepoch(), ?)
      ON CONFLICT(user) DO UPDATE SET
        label=excluded.label, contact=excluded.contact, fee_pct=excluded.fee_pct,
        hf_warn=excluded.hf_warn, hf_critical=excluded.hf_critical,
        protocol=excluded.protocol, status='active', updated_at=unixepoch(), notes=excluded.notes
    `).run(
      u, label || null, contact || null,
      fee_pct ?? RESCUE_FEE_PCT,
      hf_warn ?? 1.05, hf_critical ?? 1.02,
      protocol || "morpho", notes || null
    );
    const purged = d.prepare(`
      UPDATE liquidation_queue SET status='failed', failure_reason='rescue_client_excluded'
      WHERE lower(user)=? AND status IN ('pending','claimed','executing')
    `).run(u).changes;
    const client = d.prepare("SELECT id FROM rescue_clients WHERE user=?").get(u) as any;
    d.prepare("INSERT INTO rescue_events (client_id, user, event_type, detail, ts) VALUES (?,?,'enrolled',?,unixepoch())")
      .run(client.id, u, `queue_purged=${purged}`);
    d.close();
    res.json({ ok: true, user: u, queuePurged: purged });
  } catch (e: any) { res.json({ ok: false, error: e.message }); }
});

app.post("/api/rescue/remove", requireAuth, (req, res) => {
  try {
    const { user, reason } = req.body || {};
    if (!user) return res.json({ ok: false, error: "user required" });
    const d = rwDb();
    const u = user.toLowerCase();
    const client = d.prepare("SELECT id FROM rescue_clients WHERE user=?").get(u) as any;
    d.prepare("UPDATE rescue_clients SET status='churned', updated_at=unixepoch() WHERE user=?").run(u);
    if (client) {
      d.prepare("INSERT INTO rescue_events (client_id, user, event_type, detail, ts) VALUES (?,?,'removed',?,unixepoch())")
        .run(client.id, u, reason || "manual");
    }
    d.close();
    res.json({ ok: true });
  } catch (e: any) { res.json({ ok: false, error: e.message }); }
});

'''

    if '/api/rescue' not in intel:
        intel = intel.replace(
            'app.get("/api/env",  (_req, res) => {',
            api_block + '\napp.get("/api/env",  (_req, res) => {'
        )

    # UI tab
    if 'data-tab="rescue"' not in intel:
        intel = intel.replace(
            '  <div class="tab" data-tab="env">Env</div>\n</div>',
            '  <div class="tab" data-tab="rescue">Rescue</div>\n  <div class="tab" data-tab="env">Env</div>\n</div>'
        )

    rescue_panel = r'''
<!-- ═══════════════ RESCUE PANEL ═══════════════ -->
<div class="panel" id="panel-rescue">
  <div class="stat-bar">
    <div class="stat">
      <div class="s-lbl">Active Clients</div>
      <div class="s-val gold" id="r-clients">—</div>
      <div class="s-sub">enrolled whales</div>
    </div>
    <div class="stat">
      <div class="s-lbl">Fees Accrued</div>
      <div class="s-val gold" id="r-fees">—</div>
      <div class="s-sub">7% performance</div>
    </div>
    <div class="stat">
      <div class="s-lbl">Alerts 24h</div>
      <div class="s-val" id="r-alerts">—</div>
      <div class="s-sub">HF warnings</div>
    </div>
  </div>
  <div class="sec">
    <span class="sec-t">Rescue Desk — Client Watchlist</span>
    <span class="sec-m">liquidation-excluded · monitored</span>
  </div>
  <div class="inner">
    <div class="env-add" style="margin-bottom:21px">
      <div class="env-add-title">Enroll Whale</div>
      <div class="env-add-row" style="flex-wrap:wrap">
        <div class="env-field" style="min-width:280px"><label>Address</label>
          <input id="r-user" placeholder="0x..." autocomplete="off"></div>
        <div class="env-field"><label>Label</label>
          <input id="r-label" placeholder="Whale name"></div>
        <div class="env-field"><label>Contact</label>
          <input id="r-contact" placeholder="telegram/email"></div>
        <button class="btn" onclick="enrollRescue()">Enroll</button>
      </div>
      <span class="env-msg" id="r-msg"></span>
    </div>
    <div class="grid" id="rescue-grid"><div class="empty">Loading…</div></div>
    <div class="sec" style="margin-top:34px">
      <span class="sec-t">Recent Events</span>
    </div>
    <div class="log-area" id="rescue-events" style="max-height:240px;margin-top:13px"></div>
  </div>
</div>

'''
    if 'panel-rescue' not in intel:
        intel = intel.replace(
            '<!-- ═══════════════ ENV PANEL ═══════════════ -->',
            rescue_panel + '\n<!-- ═══════════════ ENV PANEL ═══════════════ -->'
        )

    rescue_js = r'''
// ── Rescue Desk ───────────────────────────────────────────────────────────────
const loadRescue = () => Promise.all([
  apiFetch('/api/rescue'),
  apiFetch('/api/rescue/events?limit=30')
]).then(([d, ev]) => {
  if (!d.ok) return;
  $('r-clients').textContent = d.stats?.active_clients ?? d.stats?.activeClients ?? 0;
  const fees = d.stats?.fees_accrued ?? d.stats?.feesAccruedUsd ?? 0;
  $('r-fees').textContent = '$' + Number(fees).toLocaleString('en-US',{maximumFractionDigits:0});
  $('r-alerts').textContent = d.stats?.alerts_24h ?? d.stats?.alerts24h ?? 0;
  const g = $('rescue-grid');
  const clients = d.clients || [];
  if (!clients.length) { g.innerHTML = '<div class="empty">No rescue clients enrolled</div>'; }
  else {
    g.innerHTML = clients.map(c => {
      const hf = c.health_factor;
      const cls = hf == null ? 'watch' : hf < 1.0 ? 'execute' : hf < (c.hf_critical||1.02) ? 'priority' : hf < (c.hf_warn||1.05) ? 'watch' : 'watch';
      const gap = hf ? ((hf-1)/hf*100).toFixed(2)+'%' : '—';
      return '<div class="card '+cls+'">' +
        '<div class="c-top"><span class="c-hf '+cls+'">'+(hf?Number(hf).toFixed(4):'—')+'</span>' +
        '<span class="c-tier '+cls+'">RESCUE</span></div>' +
        '<div class="c-user">'+(c.label||c.user)+'</div>' +
        '<div style="font-size:9px;color:var(--text3);margin-bottom:8px;word-break:break-all">'+c.user+'</div>' +
        '<div class="c-pos"><div class="c-side"><div class="c-side-lbl">Position</div>' +
        '<div class="c-side-asset">'+(c.live_collateral||'—')+'/'+(c.live_debt||'—')+'</div>' +
        '<div class="c-side-usd">'+fU(c.debt_value_usd)+' debt</div></div>' +
        '<div class="c-side"><div class="c-side-lbl">Gap to liq</div>' +
        '<div class="c-side-asset">'+gap+'</div>' +
        '<div class="c-side-usd">fee '+((c.fee_pct||0.07)*100).toFixed(0)+'%</div></div></div>' +
        '<div class="c-foot"><span>'+(c.contact||'no contact')+'</span>' +
        '<button class="btn-sm" onclick="removeRescue(\''+c.user+'\')">Remove</button></div></div>';
    }).join('');
  }
  const el = $('rescue-events');
  const events = ev.events || [];
  el.innerHTML = events.map(e =>
    '<span class="ll'+(e.event_type.includes('critical')||e.event_type.includes('liquidatable')?' gold':'')+'">'+
    new Date(e.ts*1000).toISOString().slice(11,19)+' '+e.event_type+' '+e.user.slice(0,10)+'… '+
    (e.health_factor?('HF='+Number(e.health_factor).toFixed(4)+' '):'')+
    (e.detail||'')+(e.fee_usd?' fee=$'+Number(e.fee_usd).toFixed(0):'')+'</span>'
  ).join('');
}).catch(() => {});

const enrollRescue = () => {
  const body = {
    user: $('r-user').value.trim(),
    label: $('r-label').value.trim(),
    contact: $('r-contact').value.trim()
  };
  fetch('/api/rescue/enroll', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) })
    .then(r => r.json()).then(d => {
      $('r-msg').textContent = d.ok ? 'Enrolled · queue purged '+d.queuePurged : (d.error||'failed');
      if (d.ok) { $('r-user').value=''; loadRescue(); }
    });
};
const removeRescue = (user) => {
  if (!confirm('Remove '+user+' from rescue desk?')) return;
  fetch('/api/rescue/remove', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({user}) })
    .then(r => r.json()).then(() => loadRescue());
};

'''
    if 'loadRescue' not in intel:
        intel = intel.replace(
            "    if (t.dataset.tab === 'env')      loadEnv();",
            "    if (t.dataset.tab === 'rescue')   loadRescue();\n    if (t.dataset.tab === 'env')      loadEnv();"
        )
        intel = intel.replace(
            'const loadMatrix = () => apiFetch',
            rescue_js + '\nconst loadMatrix = () => apiFetch'
        )

    write_remote(client, f"{ROOT}/src/intel.ts", intel)
    print("  intel.ts patched")

    print("=== .env ===")
    env = read_remote(client, f"{ROOT}/.env")
    additions = []
    for line in [
        "RESCUE_FEE_PCT=0.07",
        "RESCUE_MONITOR_INTERVAL_MS=30000",
        "RESCUE_ALERT_HF_WARN=1.05",
        "RESCUE_ALERT_HF_CRITICAL=1.02",
        "RESCUE_ALERT_DEDUPE_SEC=3600",
    ]:
        key = line.split("=")[0]
        if key not in env:
            additions.append(line)
    if additions:
        run(client, f"bash -c 'echo \"\" >> {ROOT}/.env && echo \"# Phase 2 Rescue Desk\" >> {ROOT}/.env'")
        for line in additions:
            run(client, f"bash -c 'echo \"{line}\" >> {ROOT}/.env'")
        print("  added env:", additions)
    else:
        print("  env already configured")

    print("=== schema init ===")
    init_sql = """
const { db } = require('./src/db.ts');
console.log('rescue tables ok');
"""
    # Use node to init schema via kingdom restart instead
    out = run(client, f"cd {ROOT} && npx tsx -e \"import {{ db }} from './src/db'; console.log('schema ok', db.prepare('SELECT COUNT(*) n FROM rescue_clients').get());\"" )
    print(out[:500])

    print("=== restart services ===")
    print(run(client, "pm2 restart kesov-kingdom --update-env 2>&1 | tail -5"))
    print(run(client, "pm2 restart kesov-intel --update-env 2>&1 | tail -5"))

    import time
    time.sleep(8)

    print("=== verify ===")
    checks = [
        "pm2 logs kesov-kingdom --lines 15 --nostream 2>&1 | grep -i rescue",
        "curl -sS http://127.0.0.1:5000/api/rescue 2>/dev/null | head -c 400",
        f"sqlite3 {ROOT}/kingdom.db \"SELECT name FROM sqlite_master WHERE name LIKE 'rescue%'\"",
    ]
    for cmd in checks:
        print(f"--- {cmd} ---")
        print(run(client, cmd)[:600])

    client.close()
    print("\n=== Phase 2 deploy complete ===")


if __name__ == "__main__":
    main()
