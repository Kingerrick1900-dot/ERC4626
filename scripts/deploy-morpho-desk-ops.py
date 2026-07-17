#!/usr/bin/env python3
"""Deploy Morpho desk ops: Telegram controls + guardian + quiet scaler on VPS."""
from __future__ import annotations

import datetime
import io
import os
import textwrap

import paramiko

HOST, USER, PASSWORD = "5.78.226.227", "root", "rC9jmJmhvdCh"
KING_AGENT = "/opt/elizaos-agent/king-agent"
DESK_ROOT = "/opt/morpho-desk"
TS = int(datetime.datetime.now().timestamp())

MARKET_ID = "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
DESK = "0x831b86E9AA185088CB095748bFBeF53F0D312472"
ORACLE = "0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e"
KING = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"

MORPHO_ACTIONS = r'''
// --- MORPHO_DESK (sovereign Morpho RSS/USDC) ---
const MORPHO_DESK = {
  desk: "0x831b86E9AA185088CB095748bFBeF53F0D312472" as `0x${string}`,
  oracle: "0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e" as `0x${string}`,
  morpho: "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb" as `0x${string}`,
  marketId: "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794" as `0x${string}`,
  king: "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1" as `0x${string}`,
  usdc: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" as `0x${string}`,
  rss: "0x7a305D07B537359cf468eAea9bb176E5308bC337" as `0x${string}`,
} as const;

const morphoDeskAbi = [
  { name: "healthFactor", type: "function", stateMutability: "view", inputs: [{ name: "user", type: "address" }], outputs: [{ type: "uint256" }] },
  { name: "hfFloor", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { name: "hfTarget", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { name: "marketReady", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "bool" }] },
  { name: "marketId", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "bytes32" }] },
  { name: "setFloors", type: "function", stateMutability: "nonpayable", inputs: [{ type: "uint256" }, { type: "uint256" }], outputs: [] },
  { name: "selfDeleverage", type: "function", stateMutability: "nonpayable", inputs: [{ type: "uint256" }], outputs: [] },
] as const;

const morphoBlueAbi = [
  { name: "position", type: "function", stateMutability: "view", inputs: [{ type: "bytes32" }, { type: "address" }], outputs: [{ type: "uint256" }, { type: "uint128" }, { type: "uint128" }] },
  { name: "market", type: "function", stateMutability: "view", inputs: [{ type: "bytes32" }], outputs: [{ type: "uint128" }, { type: "uint128" }, { type: "uint128" }, { type: "uint128" }, { type: "uint128" }, { type: "uint128" }] },
] as const;

function deskRpc() {
  const rpc = process.env.RSS_RPC_URL || process.env.EVM_PROVIDER_BASE || "https://base.publicnode.com";
  return createPublicClient({ chain: base, transport: fallback([http(rpc), http("https://base.publicnode.com")]) });
}

function parseWad(s: string): bigint {
  const n = Number(s);
  if (!Number.isFinite(n) || n < 1) throw new Error("HF must be >= 1");
  return BigInt(Math.round(n * 1e18));
}

export const morphoDeskStatusAction: Action = {
  name: "MORPHO_DESK_STATUS",
  similes: ["MORPHO_STATUS", "DESK_STATUS", "SOVEREIGN_DESK"],
  description: "Sovereign Morpho RSS/USDC desk: HF, supply/borrow, floors, liquid RSS, market id.",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return (
      t.includes("morpho status") ||
      t.includes("desk status") ||
      t.includes("sovereign desk") ||
      t.trim() === "morpho"
    );
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    try {
      const client = deskRpc();
      const k = MORPHO_DESK.king;
      const [hf, floor, target, ready, mid, pos, mkt, rssBal] = await Promise.all([
        client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "healthFactor", args: [k] }),
        client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "hfFloor" }),
        client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "hfTarget" }),
        client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "marketReady" }),
        client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "marketId" }),
        client.readContract({ address: MORPHO_DESK.morpho, abi: morphoBlueAbi, functionName: "position", args: [MORPHO_DESK.marketId, k] }),
        client.readContract({ address: MORPHO_DESK.morpho, abi: morphoBlueAbi, functionName: "market", args: [MORPHO_DESK.marketId] }),
        client.readContract({ address: MORPHO_DESK.rss, abi: erc20Abi, functionName: "balanceOf", args: [k] }),
      ]);
      const [supplyAssets, , borrowAssets] = mkt;
      const [, , collateral] = pos;
      const lines = [
        "**Morpho Sovereign Desk — LIVE**",
        "Desk: `" + MORPHO_DESK.desk + "`",
        "Oracle: `" + MORPHO_DESK.oracle + "` ($0.05 RSS)",
        "Market: `" + mid + "`",
        "Ready: **" + String(ready) + "**",
        "Supply: **" + formatUnits(supplyAssets, 6) + " USDC**",
        "Borrow: **" + formatUnits(borrowAssets, 6) + " USDC**",
        "RSS collateral: **" + formatUnits(collateral, 18) + "**",
        "Liquid RSS: **" + formatUnits(rssBal, 18) + "**",
        "HF: **" + formatUnits(hf, 18) + "**",
        "Floors: floor **" + formatUnits(floor, 18) + "** → target **" + formatUnits(target, 18) + "**",
        "Cmds: morpho floors 1.05 1.15 · morpho deleverage · morpho deleverage 50000",
        "_Loop is circular book — not free spendable USDC. Revenue = VIP rescue fees._",
      ];
      await reply(callback, message, lines.join("\n"));
    } catch (err) {
      await reply(callback, message, "Morpho status error: " + String(err));
    }
  },
  examples: [],
};

export const morphoDeskFloorsAction: Action = {
  name: "MORPHO_DESK_FLOORS",
  similes: ["MORPHO_FLOORS", "SET_HF_FLOORS"],
  description: "Set Morpho desk HF floor and target. Usage: morpho floors 1.05 1.15",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return t.includes("morpho floors") || t.includes("morpho floor");
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    if (!hasTokenKey()) {
      await reply(callback, message, "KING_TOKEN_PRIVATE_KEY not set.");
      return;
    }
    try {
      const raw = (message.content.text || "").trim();
      const m = raw.match(/morpho\s+floors?\s+([0-9.]+)\s+([0-9.]+)/i);
      if (!m) {
        await reply(callback, message, "Usage: morpho floors 1.05 1.15");
        return;
      }
      const floor = parseWad(m[1]);
      const target = parseWad(m[2]);
      if (target <= floor) {
        await reply(callback, message, "Target must be > floor.");
        return;
      }
      const { getRssWallet } = await import("../lib/rss-wallet.ts");
      const { walletClient, publicClient } = getRssWallet();
      const hash = await walletClient.writeContract({
        address: MORPHO_DESK.desk,
        abi: morphoDeskAbi,
        functionName: "setFloors",
        args: [floor, target],
      });
      await publicClient.waitForTransactionReceipt({ hash });
      await reply(callback, message, "Floors set. floor=" + m[1] + " target=" + m[2] + "\ntx: `" + hash + "`");
    } catch (err) {
      await reply(callback, message, "Set floors failed: " + String(err));
    }
  },
  examples: [],
};

export const morphoDeskDeleverageAction: Action = {
  name: "MORPHO_DESK_DELEVERAGE",
  similes: ["MORPHO_DELEVERAGE", "SELF_DELEVERAGE"],
  description: "Trigger Morpho self-deleverage. Usage: morpho deleverage OR morpho deleverage 50000",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return t.includes("morpho deleverage") || t.includes("self deleverage");
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    if (!hasTokenKey()) {
      await reply(callback, message, "KING_TOKEN_PRIVATE_KEY not set.");
      return;
    }
    try {
      const raw = (message.content.text || "").trim();
      const m = raw.match(/morpho\s+deleverage(?:\s+([0-9.]+))?/i);
      const client = deskRpc();
      let repay: bigint;
      if (m && m[1]) {
        repay = BigInt(Math.round(Number(m[1]) * 1e6));
      } else {
        const [hf, floor, target, mkt] = await Promise.all([
          client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "healthFactor", args: [MORPHO_DESK.king] }),
          client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "hfFloor" }),
          client.readContract({ address: MORPHO_DESK.desk, abi: morphoDeskAbi, functionName: "hfTarget" }),
          client.readContract({ address: MORPHO_DESK.morpho, abi: morphoBlueAbi, functionName: "market", args: [MORPHO_DESK.marketId] }),
        ]);
        const borrowAssets = mkt[2];
        if (hf >= floor) {
          await reply(
            callback,
            message,
            "HF " + formatUnits(hf, 18) + " >= floor " + formatUnits(floor, 18) + " — no auto repay. Pass amount: morpho deleverage 50000"
          );
          return;
        }
        repay = borrowAssets / 10n;
        if (repay < 1_000_000n) repay = 1_000_000n;
        await reply(
          callback,
          message,
          "HF " + formatUnits(hf, 18) + " < floor — deleveraging ~" + formatUnits(repay, 6) + " USDC toward " + formatUnits(target, 18) + "…"
        );
      }
      const { getRssWallet } = await import("../lib/rss-wallet.ts");
      const { walletClient, publicClient } = getRssWallet();
      const hash = await walletClient.writeContract({
        address: MORPHO_DESK.desk,
        abi: morphoDeskAbi,
        functionName: "selfDeleverage",
        args: [repay],
      });
      await publicClient.waitForTransactionReceipt({ hash });
      const hf2 = await publicClient.readContract({
        address: MORPHO_DESK.desk,
        abi: morphoDeskAbi,
        functionName: "healthFactor",
        args: [MORPHO_DESK.king],
      });
      await reply(
        callback,
        message,
        "Deleveraged **" + formatUnits(repay, 6) + " USDC**.\nNew HF: **" + formatUnits(hf2, 18) + "**\ntx: `" + hash + "`"
      );
    } catch (err) {
      await reply(callback, message, "Deleverage failed: " + String(err));
    }
  },
  examples: [],
};
'''

def run(ssh, cmd, timeout=120):
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode()
    err = stderr.read().decode()
    return out, err


def main():
    repo_bots = os.path.join(os.path.dirname(__file__), "..", "king-pod", "bots")
    guardian_path = os.path.abspath(os.path.join(repo_bots, "morpho-guardian.mjs"))
    scaler_path = os.path.abspath(os.path.join(repo_bots, "quiet-scaler.mjs"))
    with open(guardian_path) as f:
        guardian = f.read()
    with open(scaler_path) as f:
        scaler = f.read()

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASSWORD, timeout=30)
    sftp = ssh.open_sftp()

    # --- env ---
    env_path = f"{KING_AGENT}/.env"
    with sftp.open(env_path, "r") as f:
        env = f.read().decode()
    bak = f"{env_path}.bak-morpho-desk-{TS}"
    with sftp.open(bak, "w") as f:
        f.write(env)

    def upsert(env_text: str, key: str, value: str) -> str:
        lines = env_text.splitlines()
        out = []
        found = False
        for line in lines:
            if line.startswith(key + "=") or line.startswith("# " + key + "=") or line.startswith("#" + key + "="):
                out.append(f"{key}={value}")
                found = True
            else:
                out.append(line)
        if not found:
            out.append(f"{key}={value}")
        return "\n".join(out) + ("\n" if not env_text.endswith("\n") else "")

    env = upsert(env, "MORPHO_RSS_MARKET_ID", MARKET_ID)
    env = upsert(env, "MORPHO_DESK", DESK)
    env = upsert(env, "MORPHO_ORACLE", ORACLE)
    env = upsert(env, "RSS_LIQUID_RESERVE", "1000000")
    with sftp.open(env_path, "w") as f:
        f.write(env)
    print("patched .env")

    # --- telegram actions ---
    path = f"{KING_AGENT}/src/actions/rss-treasury.ts"
    with sftp.open(path, "r") as f:
        src = f.read().decode()
    with sftp.open(f"{path}.bak-morpho-desk-{TS}", "w") as f:
        f.write(src)

    if "MORPHO_DESK_STATUS" not in src:
        if "export const rssTreasuryActions" not in src:
            raise SystemExit("rssTreasuryActions export missing")
        src = src.replace(
            "export const rssTreasuryActions",
            MORPHO_ACTIONS + "\n\nexport const rssTreasuryActions",
        )
        src = src.replace(
            "export const rssTreasuryActions: Action[] = [",
            "export const rssTreasuryActions: Action[] = [\n  morphoDeskStatusAction,\n  morphoDeskFloorsAction,\n  morphoDeskDeleverageAction,",
        )
        with sftp.open(path, "w") as f:
            f.write(src)
        print("patched rss-treasury.ts morpho actions")
    else:
        print("morpho desk actions already present")

    # --- character ---
    cpath = f"{KING_AGENT}/src/character.ts"
    with sftp.open(cpath, "r") as f:
        char = f.read().decode()
    if "MORPHO_DESK_STATUS" not in char:
        needle = "RSS_TREASURY_STAKE_MORPHO"
        if needle in char:
            char = char.replace(
                needle,
                needle
                + ". MORPHO DESK: morpho status / morpho floors / morpho deleverage (MORPHO_DESK_STATUS, MORPHO_DESK_FLOORS, MORPHO_DESK_DELEVERAGE)",
                1,
            )
        with sftp.open(cpath, "w") as f:
            f.write(char)
        print("patched character")

    # --- bots on disk ---
    run(ssh, f"mkdir -p {DESK_ROOT}")
    with sftp.open(f"{DESK_ROOT}/morpho-guardian.mjs", "w") as f:
        f.write(guardian)
    with sftp.open(f"{DESK_ROOT}/quiet-scaler.mjs", "w") as f:
        f.write(scaler)

    # env file for bots (reuse king-agent secrets via symlink + overlay)
    bot_env = textwrap.dedent(
        f"""
        DESK={DESK}
        KING={KING}
        MORPHO_RSS_MARKET_ID={MARKET_ID}
        RSS_LIQUID_RESERVE=1000000
        POLL_MS=20000
        SCALE_POLL_MS=3600000
        QUIET_SCALE_ENABLED=0
        DRY_RUN=0
        """
    ).strip() + "\n"
    with sftp.open(f"{DESK_ROOT}/.env.overlay", "w") as f:
        f.write(bot_env)

    # Ensure dependencies
    out, err = run(
        ssh,
        f"cd {DESK_ROOT} && (test -d node_modules/viem || npm init -y >/dev/null 2>&1; npm install viem@2 --omit=dev 2>&1 | tail -20)",
        timeout=180,
    )
    print(out or err)

    # Start scripts that source king-agent .env + overlay
    runner_g = textwrap.dedent(
        f"""
        #!/bin/bash
        set -a
        [ -f {KING_AGENT}/.env ] && . {KING_AGENT}/.env
        [ -f {DESK_ROOT}/.env.overlay ] && . {DESK_ROOT}/.env.overlay
        set +a
        exec node {DESK_ROOT}/morpho-guardian.mjs
        """
    ).strip()
    runner_s = textwrap.dedent(
        f"""
        #!/bin/bash
        set -a
        [ -f {KING_AGENT}/.env ] && . {KING_AGENT}/.env
        [ -f {DESK_ROOT}/.env.overlay ] && . {DESK_ROOT}/.env.overlay
        set +a
        exec node {DESK_ROOT}/quiet-scaler.mjs
        """
    ).strip()
    with sftp.open(f"{DESK_ROOT}/run-guardian.sh", "w") as f:
        f.write(runner_g + "\n")
    with sftp.open(f"{DESK_ROOT}/run-scaler.sh", "w") as f:
        f.write(runner_s + "\n")
    run(ssh, f"chmod +x {DESK_ROOT}/run-guardian.sh {DESK_ROOT}/run-scaler.sh")

    out, err = run(
        ssh,
        "pm2 delete morpho-guardian 2>/dev/null; pm2 delete morpho-quiet-scaler 2>/dev/null; "
        f"pm2 start {DESK_ROOT}/run-guardian.sh --name morpho-guardian --interpreter bash && "
        f"pm2 start {DESK_ROOT}/run-scaler.sh --name morpho-quiet-scaler --interpreter bash && "
        f"pm2 restart king-agent --update-env && pm2 save && pm2 list | grep -E 'morpho-guardian|morpho-quiet|king-agent'",
        timeout=90,
    )
    print(out or err)

    # activate VIP test client if churned (opt-in path demo)
    out, err = run(
        ssh,
        "sqlite3 /opt/kesov-kingdom/kingdom.db \"UPDATE rescue_clients SET status='active' WHERE id=1 AND status='churned'; SELECT id,user,fee_pct,status FROM rescue_clients;\"",
    )
    print("rescue clients:", out or err)

    # quick guardian log
    out, err = run(ssh, "sleep 3; pm2 logs morpho-guardian --lines 8 --nostream 2>&1 | tail -20")
    print(out or err)

    sftp.close()
    ssh.close()
    print("done", TS)


if __name__ == "__main__":
    main()
