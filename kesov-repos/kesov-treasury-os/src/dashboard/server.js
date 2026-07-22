/** Phase 1 dashboard — Accounting + Oracle panel on :4000 */

import http from 'http';
import { buildSnapshot } from '../accounting/layer.js';
import { evaluateSentinel } from '../sentinel/rules.js';

const PORT = Number(process.env.PORT || 4000);

let cache = { at: 0, data: null };
const TTL_MS = 15_000;

async function getSnapshot() {
  const now = Date.now();
  if (cache.data && now - cache.at < TTL_MS) return cache.data;
  const data = await buildSnapshot();
  const sentinel = evaluateSentinel({
    oracle: data.oracle,
    snapshot: data,
    utilization: Math.max(
      ...Object.values(data.totals.morphoUtilization || {})
        .filter((x) => typeof x === 'number')
        .concat([0]),
    ),
  });
  cache = { at: now, data: { ...data, sentinel } };
  return cache.data;
}

function htmlPage(snap) {
  const feeds = (snap.oracle?.feeds || [])
    .map(
      (f) =>
        `<tr><td>${f.id}</td><td>${f.tag}</td><td>${f.stale ? 'STALE' : 'ok'}</td><td class="mono">${f.address}</td><td>${f.note || ''}</td></tr>`,
    )
    .join('');
  const assets = (snap.assets || [])
    .slice(0, 40)
    .map(
      (a) =>
        `<tr><td>${a.venue}</td><td>${a.asset}</td><td class="mono">${a.human}</td><td>${a.tag}</td><td>${a.usdMark ?? '—'}</td></tr>`,
    )
    .join('');
  const debts = (snap.debts || [])
    .map(
      (d) =>
        `<tr><td>${d.venue}</td><td>${d.asset}</td><td class="mono">${d.human}</td><td>${d.tag}</td></tr>`,
    )
    .join('');
  const pause = snap.sentinel?.pauseNewIntents;
  const reasons = (snap.sentinel?.reasons || []).join('; ') || 'none';

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>KESOV Treasury OS</title>
<style>
  :root {
    --bg0: #0c1210;
    --bg1: #14201a;
    --ink: #e8f0ea;
    --muted: #8aa394;
    --accent: #c4a35a;
    --danger: #c45c4a;
    --ok: #5a9e6f;
    --line: #24352c;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: "IBM Plex Sans", "Source Sans 3", sans-serif;
    color: var(--ink);
    background:
      radial-gradient(1200px 600px at 10% -10%, #1a2e24 0%, transparent 55%),
      radial-gradient(900px 500px at 100% 0%, #2a2418 0%, transparent 50%),
      linear-gradient(165deg, var(--bg0), var(--bg1));
    min-height: 100vh;
  }
  header {
    padding: 2rem 1.5rem 1rem;
    border-bottom: 1px solid var(--line);
  }
  .brand {
    font-family: "Cormorant Garamond", "Libre Baskerville", Georgia, serif;
    font-size: clamp(2rem, 5vw, 3.2rem);
    letter-spacing: 0.04em;
    color: var(--accent);
    margin: 0;
  }
  .sub { color: var(--muted); margin: 0.4rem 0 0; max-width: 42rem; }
  main { padding: 1.25rem 1.5rem 3rem; display: grid; gap: 1.5rem; }
  .row { display: grid; gap: 1rem; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); }
  .stat strong { display: block; font-size: 1.4rem; font-variant-numeric: tabular-nums; }
  .stat span { color: var(--muted); font-size: 0.85rem; }
  .badge {
    display: inline-block;
    padding: 0.35rem 0.7rem;
    border: 1px solid var(--line);
    color: var(--ink);
    font-size: 0.85rem;
  }
  .badge.pause { border-color: var(--danger); color: var(--danger); }
  .badge.clear { border-color: var(--ok); color: var(--ok); }
  section h2 {
    font-family: "Cormorant Garamond", Georgia, serif;
    font-weight: 600;
    font-size: 1.35rem;
    margin: 0 0 0.6rem;
    color: var(--accent);
  }
  table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  th, td { text-align: left; padding: 0.45rem 0.35rem; border-bottom: 1px solid var(--line); vertical-align: top; }
  th { color: var(--muted); font-weight: 500; }
  .mono { font-family: "IBM Plex Mono", ui-monospace, monospace; font-size: 0.82rem; }
  .warn { color: var(--danger); }
  footer { color: var(--muted); font-size: 0.8rem; padding: 0 1.5rem 2rem; }
  a { color: var(--accent); }
</style>
<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@600;700&family=IBM+Plex+Sans:wght@400;500&family=IBM+Plex+Mono&display=swap" rel="stylesheet"/>
</head>
<body>
  <header>
    <p class="brand">KESOV</p>
    <p class="sub">Treasury OS — Accounting & Oracle (Phase 1). Synthetic RSS/kUSD never blended into external solvency.</p>
  </header>
  <main>
    <div class="row">
      <div class="stat"><strong>$${snap.totals.externalNetUsd}</strong><span>external net USD</span></div>
      <div class="stat"><strong>$${snap.totals.syntheticMarkedUsd}</strong><span>synthetic marked (informational)</span></div>
      <div class="stat"><strong>$${snap.totals.externalDebtUsd}</strong><span>external debt USD</span></div>
      <div class="stat">
        <span class="badge ${pause ? 'pause' : 'clear'}">${pause ? 'PAUSE new intents' : 'Intents open'}</span>
        <span style="display:block;margin-top:0.4rem;color:var(--muted);font-size:0.8rem">${reasons}</span>
      </div>
    </div>

    <section>
      <h2>Oracle Manager</h2>
      <table>
        <thead><tr><th>Feed</th><th>Tag</th><th>Status</th><th>Address</th><th>Note</th></tr></thead>
        <tbody>${feeds}</tbody>
      </table>
    </section>

    <section>
      <h2>Flags</h2>
      <p class="mono">zkProven=${snap.flags.zkProven} · forceDeallocatePenalty=${snap.flags.forceDeallocatePenaltyWad} · ok=${snap.flags.forceDeallocatePenaltyOk}</p>
      <p class="sub">${snap.flags.note}</p>
    </section>

    <section>
      <h2>Assets (sample)</h2>
      <table>
        <thead><tr><th>Venue</th><th>Asset</th><th>Amount</th><th>Tag</th><th>USD mark</th></tr></thead>
        <tbody>${assets || '<tr><td colspan="5">none</td></tr>'}</tbody>
      </table>
    </section>

    <section>
      <h2>Debts</h2>
      <table>
        <thead><tr><th>Venue</th><th>Asset</th><th>Amount</th><th>Tag</th></tr></thead>
        <tbody>${debts || '<tr><td colspan="4">none</td></tr>'}</tbody>
      </table>
    </section>
  </main>
  <footer>
    asOf ${snap.asOf} · <a href="/api/snapshot">/api/snapshot</a> · refresh ~15s cache · Phase 1 read-only
  </footer>
</body>
</html>`;
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/health') {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
      return;
    }
    if (req.url === '/api/snapshot') {
      const snap = await getSnapshot();
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify(snap, null, 2));
      return;
    }
    if (req.url === '/' || req.url?.startsWith('/index')) {
      const snap = await getSnapshot();
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      res.end(htmlPage(snap));
      return;
    }
    res.writeHead(404);
    res.end('not found');
  } catch (e) {
    res.writeHead(500, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: String(e?.message || e) }));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`KESOV Treasury OS dashboard http://0.0.0.0:${PORT}`);
});
