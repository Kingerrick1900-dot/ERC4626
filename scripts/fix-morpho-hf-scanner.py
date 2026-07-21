#!/usr/bin/env python3
"""Fix Morpho scanner stale HF — always upsert live on-chain HF; chain-only BACKRUN fire."""
from __future__ import annotations

import datetime
import paramiko
import textwrap

HOST, USER, PASSWORD = "5.78.226.227", "root", "rC9jmJmhvdCh"
ROOT = "/opt/kesov-kingdom"
TS = int(datetime.datetime.now().timestamp())

DB_CLEAR_FN = textwrap.dedent('''
export function clearAtRiskState(user: string, collateral_asset: string, debt_asset: string): void {
  db.prepare(
    "DELETE FROM potential_targets WHERE user=? AND collateral_asset=? AND debt_asset=?"
  ).run(user, collateral_asset, debt_asset);
  db.prepare(`
    UPDATE liquidation_queue
    SET status='failed', failure_reason='healthy_on_chain'
    WHERE lower(user)=lower(?) AND collateral_asset=? AND debt_asset=?
      AND status IN ('pending','claimed','executing')
  `).run(user, collateral_asset, debt_asset);
}
''')

SCANNER_OLD = """      let hf: number;
      try {
        const colInLoan = collateral.mul(oraclePrice).div(SCALE);
        const maxBorrow = colInLoan.mul(lltv).div(WAD);
        if (borrowAssets.isZero()) continue;
        hf = parseFloat(ethers.utils.formatUnits(maxBorrow.mul(WAD).div(borrowAssets), 18));
      } catch { continue; }
      if (hf <= 0 || hf > 3) continue;

      const collateralUsd = parseFloat(ethers.utils.formatUnits(collateral, market.collateralDecimals)) * colPriceUsd;
      const debtUsd       = parseFloat(ethers.utils.formatUnits(borrowAssets, market.loanDecimals))    * loanPriceUsd;
      if (collateralUsd < 100 || debtUsd < 100) continue;
      if (EXCLUDED_SYMBOLS.has(market.collateralSymbol) || EXCLUDED_SYMBOLS.has(market.loanSymbol)) continue;
      if (hf >= 1.01) { ghostUsers.push(slice[i]); continue; }

      const lltvFloat = parseFloat(ethers.utils.formatUnits(lltv, 18));
      const liqBonus  = Math.max(1.01, 1 + (1 - lltvFloat) * 0.5);

      upsertScannerRecord({
        user:               slice[i],
        collateral_asset:   market.collateralToken,
        collateral_symbol:  market.collateralSymbol || "?",
        debt_asset:         market.loanToken,
        debt_symbol:        market.loanSymbol || "?",
        collateral_value_usd: collateralUsd,
        debt_value_usd:     debtUsd,
        health_factor:      hf,
        debt_to_cover:      debtUsd * 0.5,
        liquidation_bonus:  liqBonus,
        block_number:       block,
        timestamp:          ts,
        protocol:           "morpho",
        market_id:          marketId,
      });
      counters.stored++;

      if (hf < 1.05) {
        console.log(`[morpho] 🔴 AT-RISK hf=${hf.toFixed(4)} col=$${collateralUsd.toFixed(0)} debt=$${debtUsd.toFixed(0)} ${market.collateralSymbol}/${market.loanSymbol} ${slice[i]}`);
      }
    }
    await sleep(80);
    if (ghostUsers.length > 0) { pruneStaleRecords(ghostUsers); }"""

SCANNER_NEW = """      let hf: number;
      try {
        const colInLoan = collateral.mul(oraclePrice).div(SCALE);
        const maxBorrow = colInLoan.mul(lltv).div(WAD);
        if (borrowAssets.isZero()) continue;
        // Live on-chain HF — same formula as executor-morpho onChainHF()
        hf = maxBorrow.mul(1_000_000).div(borrowAssets).toNumber() / 1_000_000;
      } catch { continue; }
      if (!isFinite(hf) || hf <= 0) continue;

      const collateralUsd = parseFloat(ethers.utils.formatUnits(collateral, market.collateralDecimals)) * colPriceUsd;
      const debtUsd       = parseFloat(ethers.utils.formatUnits(borrowAssets, market.loanDecimals))    * loanPriceUsd;
      if (collateralUsd < 100 || debtUsd < 100) continue;
      if (EXCLUDED_SYMBOLS.has(market.collateralSymbol) || EXCLUDED_SYMBOLS.has(market.loanSymbol)) continue;

      const lltvFloat = parseFloat(ethers.utils.formatUnits(lltv, 18));
      const liqBonus  = Math.max(1.01, 1 + (1 - lltvFloat) * 0.5);

      // Always persist live on-chain HF — never skip healthy positions (fixes phantom 1.0004 vs 6.07)
      upsertScannerRecord({
        user:               slice[i],
        collateral_asset:   market.collateralToken,
        collateral_symbol:  market.collateralSymbol || "?",
        debt_asset:         market.loanToken,
        debt_symbol:        market.loanSymbol || "?",
        collateral_value_usd: collateralUsd,
        debt_value_usd:     debtUsd,
        health_factor:      hf,
        debt_to_cover:      debtUsd * 0.5,
        liquidation_bonus:  liqBonus,
        block_number:       block,
        timestamp:          ts,
        protocol:           "morpho",
        market_id:          marketId,
      });
      counters.stored++;

      if (hf >= 1.15) {
        clearAtRiskState(slice[i], market.collateralToken, market.loanToken);
        continue;
      }

      if (hf < 1.05) {
        console.log(`[morpho] 🔴 AT-RISK hf=${hf.toFixed(4)} col=$${collateralUsd.toFixed(0)} debt=$${debtUsd.toFixed(0)} ${market.collateralSymbol}/${market.loanSymbol} ${slice[i]}`);
      }
    }
    await sleep(80);"""

BACKRUN_OLD = """    // On-chain HF < 1.0 is authoritative; DB HF is early-warning only
    const fireThreshold = (target.priority_score || 0) >= 999985 ? 1.001 : 1.0;
    const chainLiquidatable = chainHF !== null && chainHF < 1.0;
    const dbEarlyFire = dbHF < fireThreshold;
    if (chainLiquidatable || dbEarlyFire) {
      const hfTag = chainHF !== null ? `CHAIN_HF=${chainHF.toFixed(6)}` : `DB_HF=${dbHF.toFixed(6)}`;
      console.log(`[morpho-exec] 🔥 BACKRUN FIRE ${target.user.slice(0,10)} ${hfTag} db=${dbHF.toFixed(6)} priority=${target.priority_score} — EXECUTING`);
      backrunActive.delete(target.id);
      await fireMorphoLiquidation(target, provider);
      return;
    }"""

BACKRUN_NEW = """    // On-chain HF < 1.0 is the ONLY fire signal — DB HF never triggers execution
    const chainLiquidatable = chainHF !== null && chainHF < 1.0;
    if (chainHF !== null && dbHF < 1.15 && chainHF >= 1.5) {
      console.log(`[morpho-exec] 👻 PHANTOM ${target.user.slice(0,10)} db=${dbHF.toFixed(4)} chain=${chainHF.toFixed(4)} — releasing`);
      releaseTarget(target.id);
      backrunActive.delete(target.id);
      return;
    }
    if (chainLiquidatable) {
      console.log(`[morpho-exec] 🔥 BACKRUN FIRE ${target.user.slice(0,10)} CHAIN_HF=${chainHF!.toFixed(6)} db=${dbHF.toFixed(6)} priority=${target.priority_score} — EXECUTING`);
      backrunActive.delete(target.id);
      await fireMorphoLiquidation(target, provider);
      return;
    }"""


def ssh():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username=USER, password=PASSWORD, timeout=20, allow_agent=False, look_for_keys=False)
    return c


def run(c, cmd, t=120):
    _, o, e = c.exec_command(cmd, timeout=t)
    return (o.read() + e.read()).decode()


def read(c, path):
    return run(c, f"cat {path}")


def write(c, path, content):
    import base64
    b64 = base64.b64encode(content.encode()).decode()
    run(c, f"python3 -c \"import base64; open('{path}','wb').write(base64.b64decode('{b64}'))\"")


def patch(c, path, old, new, label):
    content = read(c, path)
    if old not in content:
        raise RuntimeError(f"{label}: anchor missing in {path}")
    run(c, f"cp {path} {path}.bak-hf-fix-{TS}")
    write(c, path, content.replace(old, new, 1))
    print(f"  patched {label}")


def main():
    c = ssh()

    print("=== db.ts clearAtRiskState ===")
    db = read(c, f"{ROOT}/src/db.ts")
    if "clearAtRiskState" not in db:
        db = db.rstrip() + "\n" + DB_CLEAR_FN + "\n"
        run(c, f"cp {ROOT}/src/db.ts {ROOT}/src/db.ts.bak-hf-fix-{TS}")
        write(c, f"{ROOT}/src/db.ts", db)
        print("  added clearAtRiskState")
    else:
        print("  already present")

    print("=== scanner-morpho.ts ===")
    sm = read(c, f"{ROOT}/src/scanner-morpho.ts")
    if "clearAtRiskState" not in sm:
        sm = sm.replace(
            'import { upsertScannerRecord, logEvent, pruneStaleRecords } from "./db";',
            'import { upsertScannerRecord, logEvent, clearAtRiskState } from "./db";',
        )
        run(c, f"cp {ROOT}/src/scanner-morpho.ts {ROOT}/src/scanner-morpho.ts.bak-hf-fix-{TS}")
        write(c, f"{ROOT}/src/scanner-morpho.ts", sm)
        print("  updated import")
    patch(c, f"{ROOT}/src/scanner-morpho.ts", SCANNER_OLD, SCANNER_NEW, "scanOneMarket HF logic")

    print("=== executor-morpho.ts BACKRUN ===")
    patch(c, f"{ROOT}/src/executor-morpho.ts", BACKRUN_OLD, BACKRUN_NEW, "BACKRUN chain-only fire")

    print("=== purge phantom queue rows ===")
    print(run(c, f"""sqlite3 {ROOT}/kingdom.db "
UPDATE liquidation_queue SET status='failed', failure_reason='phantom_hf_purge'
WHERE protocol='morpho' AND status IN ('pending','claimed','executing')
  AND user IN (SELECT user FROM scanner_records WHERE health_factor < 1.02 AND datetime(timestamp,'unixepoch') < datetime('now','-1 day'));
SELECT changes();
" """))

    print("=== restart kesov-kingdom ===")
    print(run(c, "pm2 restart kesov-kingdom --update-env 2>&1 | tail -3"))

    import time
    print("waiting 90s for morpho scan cycle...")
    time.sleep(90)

    USER = "0x5a820bd80a297454c0edd28fc3a3e959c6f2f4fa"
    print("\n=== verify 0x5a820bd8 HF in DB ===")
    print(run(c, f"""sqlite3 {ROOT}/kingdom.db "
SELECT ROUND(health_factor,4) hf, ROUND(debt_value_usd,0) debt, datetime(timestamp,'unixepoch') ts, datetime(scanned_at,'unixepoch') scanned
FROM scanner_records WHERE lower(user)=lower('{USER}');
SELECT risk_tier, ROUND(health_factor,4) hf FROM potential_targets WHERE lower(user)=lower('{USER}');
" """))

    print("\n=== morpho scanner logs ===")
    print(run(c, "pm2 logs kesov-kingdom --lines 40 --nostream 2>&1 | grep -iE 'morpho.*scan|AT-RISK|5a820bd8|phantom|priority markets' | tail -15"))

    c.close()
    print("\n=== HF fix deploy complete ===")


if __name__ == "__main__":
    main()
