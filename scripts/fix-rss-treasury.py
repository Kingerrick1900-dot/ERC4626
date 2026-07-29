#!/usr/bin/env python3
"""Deploy RSS_TREASURY actions — separate token wallet (0x6708), fleet EVM key unchanged."""
import base64
import datetime
import os
import paramiko
import time

HOST, USER, PASSWORD = "5.78.226.227", "root", "rC9jmJmhvdCh"
ROOT = "/opt/elizaos-agent/king-agent"
TS = int(datetime.datetime.now().timestamp())

RSS_WALLET_TS = r'''import {
  createPublicClient,
  createWalletClient,
  erc20Abi,
  fallback,
  formatUnits,
  http,
  type Address,
  type Hash,
  type Transport,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";

export const RSS_DECIMALS = 18;
export const RSS_TOKEN = (process.env.RSS_TOKEN_ADDRESS || "0x7a305D07B537359cf468eAea9bb176E5308bC337") as Address;
export const KING_TOKEN_ADDRESS = (process.env.KING_TOKEN_ADDRESS || "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1") as Address;
export const MORPHO_BLUE = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb" as Address;
export const LIQUID_RESERVE_RAW =
  BigInt(process.env.RSS_LIQUID_RESERVE || "21000000") * 10n ** BigInt(RSS_DECIMALS);

function rpcUrls(): string[] {
  const urls: string[] = [];
  const add = (u?: string | null) => {
    const t = u?.trim();
    if (t && !urls.includes(t)) urls.push(t);
  };
  add(process.env.RSS_RPC_URL);
  add(process.env.RPC_PRIVATE_DRPC);
  add(process.env.EVM_PROVIDER_BASE);
  add(process.env.RPC_URL);
  add("https://base.publicnode.com");
  add("https://base.llamarpc.com");
  return urls;
}

function getTransport(): Transport {
  const urls = rpcUrls();
  if (!urls.length) return http("https://base.publicnode.com");
  if (urls.length === 1) return http(urls[0]);
  return fallback(urls.map((u) => http(u)));
}

export function hasTokenKey(): boolean {
  return Boolean(process.env.KING_TOKEN_PRIVATE_KEY?.trim());
}

export function getTokenAccount() {
  const pk = process.env.KING_TOKEN_PRIVATE_KEY?.trim();
  if (!pk) throw new Error("KING_TOKEN_PRIVATE_KEY not set — add King's RSS wallet key to .env");
  const key = (pk.startsWith("0x") ? pk : `0x${pk}`) as `0x${string}`;
  return privateKeyToAccount(key);
}

export function getPublicClient() {
  return createPublicClient({ chain: base, transport: getTransport() });
}

export function getRssWallet() {
  const account = getTokenAccount();
  const transport = getTransport();
  if (account.address.toLowerCase() !== KING_TOKEN_ADDRESS.toLowerCase()) {
    throw new Error(`KING_TOKEN_PRIVATE_KEY signs as ${account.address}, expected ${KING_TOKEN_ADDRESS}`);
  }
  return {
    account,
    publicClient: createPublicClient({ chain: base, transport }),
    walletClient: createWalletClient({ chain: base, transport, account }),
  };
}

export async function readRssBalance(address: Address = KING_TOKEN_ADDRESS): Promise<bigint> {
  return getPublicClient().readContract({
    address: RSS_TOKEN,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address],
  });
}

export async function readEthBalance(address: Address = KING_TOKEN_ADDRESS): Promise<bigint> {
  return getPublicClient().getBalance({ address });
}

export function stakeableAmount(balance: bigint): bigint {
  if (balance <= LIQUID_RESERVE_RAW) return 0n;
  return balance - LIQUID_RESERVE_RAW;
}

export function fmtRss(raw: bigint): string {
  return `${formatUnits(raw, RSS_DECIMALS)} RSS`;
}

type PreparedTx = { to: Address; data: `0x${string}`; value?: bigint; chainId?: number };

export async function runMorphoPrepare(args: string[]): Promise<{ transactions?: PreparedTx[]; warnings?: string[]; error?: string }> {
  const proc = Bun.spawn(["npx", "@morpho-org/cli@latest", ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: process.env,
  });
  const [stdout, stderr, code] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  if (code !== 0) return { error: stderr.trim() || stdout.trim() || `morpho cli exit ${code}` };
  try {
    return JSON.parse(stdout);
  } catch {
    return { error: `Invalid morpho CLI JSON: ${stdout.slice(0, 400)}` };
  }
}

export async function broadcastPreparedTxs(txs: PreparedTx[]): Promise<Hash[]> {
  const { walletClient, publicClient } = getRssWallet();
  const hashes: Hash[] = [];
  for (const tx of txs) {
    const hash = await walletClient.sendTransaction({
      to: tx.to,
      data: tx.data,
      value: tx.value ?? 0n,
      chain: base,
    });
    await publicClient.waitForTransactionReceipt({ hash });
    hashes.push(hash);
  }
  return hashes;
}

const ENV_PATH = process.env.KING_AGENT_ENV_PATH || "/opt/elizaos-agent/king-agent/.env";

export function extractPrivateKey(text: string): `0x${string}` | null {
  const compact = text.replace(/\s/g, "");
  const m = compact.match(/(?:0x)?([a-fA-F0-9]{64})/);
  return m ? (`0x${m[1]}` as `0x${string}`) : null;
}

export async function persistTokenPrivateKey(privateKey: `0x${string}`): Promise<void> {
  const account = privateKeyToAccount(privateKey);
  if (account.address.toLowerCase() !== KING_TOKEN_ADDRESS.toLowerCase()) {
    throw new Error(`Key is for ${account.address}, expected treasury ${KING_TOKEN_ADDRESS}`);
  }
  let env = await Bun.file(ENV_PATH).text();
  const line = `KING_TOKEN_PRIVATE_KEY=${privateKey}`;
  if (/^KING_TOKEN_PRIVATE_KEY=.*/m.test(env)) {
    env = env.replace(/^KING_TOKEN_PRIVATE_KEY=.*/m, line);
  } else if (/^# KING_TOKEN_PRIVATE_KEY.*/m.test(env)) {
    env = env.replace(/^# KING_TOKEN_PRIVATE_KEY.*/m, line);
  } else {
    env = env.trimEnd() + `\n${line}\n`;
  }
  await Bun.write(ENV_PATH, env);
}

export function scheduleAgentRestart(): void {
  Bun.spawn(["pm2", "restart", "king-agent", "--update-env"], {
    stdout: "ignore",
    stderr: "ignore",
  });
}
'''

RSS_TREASURY_TS = r'''import type { Action, IAgentRuntime, Memory, State } from "@elizaos/core";
import { isAuthorized, reply, textMatches } from "../lib/fleet-exec.ts";
import { formatUnits } from "viem";
import {
  KING_TOKEN_ADDRESS,
  LIQUID_RESERVE_RAW,
  RSS_TOKEN,
  extractPrivateKey,
  fmtRss,
  hasTokenKey,
  persistTokenPrivateKey,
  readEthBalance,
  readRssBalance,
  runMorphoPrepare,
  broadcastPreparedTxs,
  scheduleAgentRestart,
  stakeableAmount,
} from "../lib/rss-wallet.ts";

const deny = async (cb: Parameters<typeof reply>[0], msg: Memory) => reply(cb, msg, "Unauthorized.");

function morphoMarketId(): string | null {
  const id = process.env.MORPHO_RSS_MARKET_ID?.trim();
  return id || null;
}

async function morphoMarketExists(): Promise<boolean> {
  const id = morphoMarketId();
  if (!id) return false;
  const out = await runMorphoPrepare([
    "query-markets",
    "--chain",
    "base",
    "--collateral-asset",
    RSS_TOKEN,
    "--limit",
    "5",
  ]);
  if (out.error) return false;
  const markets = (out as { markets?: unknown[] }).markets;
  return Array.isArray(markets) && markets.length > 0;
}

export const rssTreasuryStatusAction: Action = {
  name: "RSS_TREASURY_STATUS",
  similes: ["RSS_BALANCE", "TOKEN_TREASURY_STATUS", "ELE_BALANCE"],
  description:
    "RSS token treasury status for King's dedicated wallet (0x6708). Shows RSS balance, ETH for gas, liquid reserve, stakeable amount, Morpho market status. Uses KING_TOKEN wallet only — NOT fleet EVM key.",
  validate: async (_rt: IAgentRuntime, message: Memory) => {
    const t = (message.content.text || "").toLowerCase();
    return textMatches(t, [
      "rss balance",
      "rss status",
      "rss treasury",
      "token treasury",
      "elephant token",
      "ele balance",
      "rss wallet",
    ]);
  },
  handler: async (_rt, message, _state, _opts, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    try {
      const [rss, eth] = await Promise.all([readRssBalance(), readEthBalance()]);
      const stakeable = stakeableAmount(rss);
      const marketId = morphoMarketId();
      const marketLive = marketId ? await morphoMarketExists() : false;
      const keyOk = hasTokenKey();
      const lines = [
        `**RSS Treasury** — ${KING_TOKEN_ADDRESS}`,
        `Token: \`${RSS_TOKEN}\``,
        `Balance: **${fmtRss(rss)}**`,
        `ETH (gas): **${Number(eth) / 1e18}**`,
        `Liquid reserve (do not stake): **${fmtRss(LIQUID_RESERVE_RAW)}**`,
        `Stakeable now: **${fmtRss(stakeable)}**`,
        `KING_TOKEN_PRIVATE_KEY: ${keyOk ? "configured" : "**NOT SET**"}`,
        `Morpho market: ${marketLive ? `yes (\`${marketId}\`)` : marketId ? `id set but market not found` : "none — set MORPHO_RSS_MARKET_ID after createMarket"}`,
        `Fleet EVM key (0xcbD8…): separate — unchanged`,
      ];
      await reply(callback, message, lines.join("\n"));
    } catch (err) {
      await reply(callback, message, `RSS treasury error: ${String(err)}`);
    }
  },
  examples: [],
};

export const rssTreasuryStakeMorphoAction: Action = {
  name: "RSS_TREASURY_STAKE_MORPHO",
  similes: ["RSS_STAKE", "STAKE_ELE_MORPHO", "STAKE_RSS"],
  description:
    "Stake RSS from King's token wallet into Morpho Blue as collateral. Keeps RSS_LIQUID_RESERVE (21M) in wallet. Requires KING_TOKEN_PRIVATE_KEY + MORPHO_RSS_MARKET_ID + ETH gas. Never uses fleet EVM_PRIVATE_KEY.",
  validate: async (_rt: IAgentRuntime, message: Memory) => {
    const t = (message.content.text || "").toLowerCase();
    return textMatches(t, ["rss stake", "stake rss", "stake morpho", "stake ele", "stake elephant", "morpho stake rss"]);
  },
  handler: async (_rt, message, _state, _opts, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    if (!hasTokenKey()) {
      return reply(callback, message, "KING_TOKEN_PRIVATE_KEY not set in .env — fleet key is not used for RSS.");
    }
    const marketId = morphoMarketId();
    if (!marketId) {
      return reply(
        callback,
        message,
        "No Morpho market for RSS on Base yet. Set MORPHO_RSS_MARKET_ID after createMarket, then retry.",
      );
    }
    try {
      const balance = await readRssBalance();
      const amount = stakeableAmount(balance);
      if (amount <= 0n) {
        return reply(
          callback,
          message,
          `Nothing to stake. Balance ${fmtRss(balance)} — reserve ${fmtRss(LIQUID_RESERVE_RAW)} must stay liquid. Withdraw RSS from 0x9022… to treasury wallet first.`,
        );
      }
      const eth = await readEthBalance();
      if (eth === 0n) {
        return reply(callback, message, "Treasury wallet has 0 ETH — send Base ETH to 0x6708… for gas.");
      }
      const amountHuman = formatUnits(amount, RSS_DECIMALS);
      const prepared = await runMorphoPrepare([
        "prepare-supply-collateral",
        "--chain",
        "base",
        "--market-id",
        marketId,
        "--user-address",
        KING_TOKEN_ADDRESS,
        "--amount",
        amountHuman,
      ]);
      if (prepared.error) {
        return reply(callback, message, `Morpho prepare failed: ${prepared.error}`);
      }
      const txs = prepared.transactions || [];
      if (!txs.length) {
        const warn = (prepared.warnings || []).join("; ");
        return reply(callback, message, `No transactions prepared. ${warn}`);
      }
      const hashes = await broadcastPreparedTxs(txs);
      await reply(
        callback,
        message,
        `**RSS staked to Morpho**\nAmount: **${fmtRss(amount)}**\nMarket: \`${marketId}\`\nTx: ${hashes.map((h) => `\`${h}\``).join(", ")}`,
      );
    } catch (err) {
      await reply(callback, message, `RSS stake failed: ${String(err)}`);
    }
  },
  examples: [],
};

export const rssTreasurySetKeyAction: Action = {
  name: "RSS_TREASURY_SET_KEY",
  similes: ["WIRE_RSS_KEY", "SET_RSS_KEY", "RSS_WIRE_KEY"],
  description:
    "MANDATORY when King sends 'wire rss key' or 'set rss key'. Saves RSS treasury private key for 0x6708… to server .env and restarts agent. Use this action ONLY — never FLEET_STATUS for key wiring. Never echo key back.",
  validate: async (_rt: IAgentRuntime, message: Memory) => {
    const lower = (message.content.text || "").toLowerCase();
    return textMatches(lower, [
      "wire rss key",
      "set rss key",
      "rss private key",
      "wire treasury key",
      "set treasury key",
      "wire rss private",
    ]);
  },
  handler: async (_rt, message, _state, _opts, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    const text = message.content.text || "";
    const key = extractPrivateKey(text);
    if (!key) {
      return reply(
        callback,
        message,
        "Paste the **full** 64-character private key in one message:\n`wire rss key 0x<64 hex chars>`\nMust be for treasury wallet 0x6708… — not the fleet key.",
      );
    }
    try {
      await persistTokenPrivateKey(key);
      process.env.KING_TOKEN_PRIVATE_KEY = key;
      scheduleAgentRestart();
      await reply(
        callback,
        message,
        "RSS treasury key saved for 0x6708… Fleet key unchanged. Scribe is restarting — delete this message, then send `rss status` in ~15 seconds.",
      );
    } catch (err) {
      await reply(callback, message, `Could not save RSS key: ${String(err)}`);
    }
  },
  examples: [],
};

export const rssTreasuryActions: Action[] = [
  rssTreasurySetKeyAction,
  rssTreasuryStatusAction,
  rssTreasuryStakeMorphoAction,
];
'''

DIRECT_REPLY_TS = r'''import type { Action, IAgentRuntime, Memory, State } from "@elizaos/core";
import { isAuthorized, reply, textMatches } from "../lib/fleet-exec.ts";
import {
  extractPrivateKey,
  persistTokenPrivateKey,
  scheduleAgentRestart,
} from "../lib/rss-wallet.ts";

/** Strip accidental King-Errick roleplay from model output. */
function sanitizeScribeText(raw: string): string {
  let t = raw.trim();
  if (!t) return t;

  const kingVoice = [
    /^I am King Errick[^.]*\.?\s*/i,
    /^I am the King[^.]*\.?\s*/i,
    /^The King is here[^.]*\.?\s*/i,
    /^I,? King Errick,?\s*/i,
    /^I will assume the (?:mantle|persona) of King Errick[^.]*\.?\s*/i,
    /^I assume the (?:mantle|persona) of King Errick[^.]*\.?\s*/i,
    /^As King Errick,?\s*/i,
    /^My kingdom\b[^.]*\.?\s*/i,
    /^The Kingdom of Base demands[^.]*\.?\s*/i,
  ];
  for (const re of kingVoice) {
    t = t.replace(re, "");
  }

  t = t.replace(/\bmy absolute command\b/gi, "your command");
  t = t.replace(/\bunder my command\b/gi, "at your command");
  t = t.replace(/\bmy Fleet\b/g, "the Fleet");
  t = t.replace(/\bmy fleet\b/g, "the fleet");

  // Drop empty "initiated status check" fluff — fleet/rss actions send real data
  if (/initiated (?:a )?(?:full )?status check/i.test(t) && t.length < 220) {
    return "";
  }

  return t.trim() || raw.trim();
}

/** Pull plain text from Eliza's first-pass XML parse (no second LLM call). */
function pickReplyText(state?: State, responses?: Memory[]): string {
  if (responses?.length) {
    for (const r of responses) {
      const c = r?.content as Record<string, unknown> | undefined;
      const t = c?.text;
      if (typeof t === "string" && t.trim()) return sanitizeScribeText(t);
    }
  }
  const s = state as Record<string, unknown> | undefined;
  for (const key of ["text", "messageText", "responseText", "agentResponse"]) {
    const v = s?.[key];
    if (typeof v === "string" && v.trim()) return sanitizeScribeText(v);
  }
  const agents = s?.agents as Record<string, { text?: string }> | undefined;
  if (agents) {
    for (const a of Object.values(agents)) {
      if (typeof a?.text === "string" && a.text.trim()) return sanitizeScribeText(a.text);
    }
  }
  return "";
}

async function tryWireRssKey(message: Memory, callback: Parameters<typeof reply>[0]): Promise<boolean> {
  const userText = message.content.text || "";
  const lower = userText.toLowerCase();
  if (
    !textMatches(lower, [
      "wire rss key",
      "set rss key",
      "rss private key",
      "wire treasury key",
      "set treasury key",
    ])
  ) {
    return false;
  }
  if (!isAuthorized(message)) {
    await reply(callback, message, "Unauthorized.");
    return true;
  }
  const key = extractPrivateKey(userText);
  if (!key) {
    await reply(
      callback,
      message,
      "Paste the **full** 64-character private key in **one** message:\n`wire rss key 0x<64 hex chars>`\nMust be for treasury `0x6708…` — not the fleet key.",
    );
    return true;
  }
  try {
    await persistTokenPrivateKey(key);
    process.env.KING_TOKEN_PRIVATE_KEY = key;
    scheduleAgentRestart();
    await reply(
      callback,
      message,
      "RSS treasury key saved for 0x6708… Fleet key unchanged. Scribe is restarting — **delete this message**, then send `rss status` in ~15 seconds.",
    );
  } catch (err) {
    await reply(callback, message, `Could not save RSS key: ${String(err)}`);
  }
  return true;
}

/**
 * Forked REPLY — bootstrap is off, so we register REPLY ourselves.
 * Intercepts `wire rss key` on the King's incoming message (Plan B).
 */
export const directReplyAction: Action = {
  name: "REPLY",
  similes: ["GREET", "RESPOND", "RESPONSE", "SEND_REPLY", "REPLY_TO_MESSAGE", "CHAT"],
  description:
    "Default conversational reply as Scribe to King Errick. For wire rss key messages, saves key instead of chatting. Never speak as King Errick.",
  validate: async () => true,
  handler: async (_rt: IAgentRuntime, message: Memory, state: State, _opts, callback, responses) => {
    if (await tryWireRssKey(message, callback)) {
      return { text: "rss key handled", success: true, values: { responded: true } };
    }
    const text = pickReplyText(state, responses as Memory[] | undefined);
    if (!text) {
      return { text: "", success: true, values: { responded: false, skippedFluff: true } };
    }
    await reply(callback, message, text || "Understood, Your Majesty.");
    return { text, success: true, values: { responded: true, lastReply: text } };
  },
  examples: [],
};
'''

def ssh():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username=USER, password=PASSWORD, timeout=20, allow_agent=False, look_for_keys=False)
    return c


def run(c, cmd, t=120):
    _, o, e = c.exec_command(cmd, timeout=t)
    return (o.read() + e.read()).decode()


def write(c, path, content):
    b64 = base64.b64encode(content.encode()).decode()
    run(c, f"python3 -c \"import base64; open('{path}','wb').write(base64.b64decode('{b64}'))\"")


def patch_env(c, king_drpc: str | None = None):
    env = run(c, f"cat {ROOT}/.env")
    drpc = (king_drpc or "").strip()
    lines_to_add = []
    if "KING_TOKEN_ADDRESS=" not in env:
        lines_to_add.append("KING_TOKEN_ADDRESS=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1")
    if "RSS_TOKEN_ADDRESS=" not in env:
        lines_to_add.append("RSS_TOKEN_ADDRESS=0x7a305D07B537359cf468eAea9bb176E5308bC337")
    if "RSS_LIQUID_RESERVE=" not in env:
        lines_to_add.append("RSS_LIQUID_RESERVE=21000000")
    if "KING_TOKEN_PRIVATE_KEY=" not in env and "# KING_TOKEN_PRIVATE_KEY" not in env:
        lines_to_add.append("# KING_TOKEN_PRIVATE_KEY=0x...  # or: wire rss key 0x... in Telegram")
    if "MORPHO_RSS_MARKET_ID=" not in env and "# MORPHO_RSS_MARKET_ID" not in env:
        lines_to_add.append("# MORPHO_RSS_MARKET_ID=  # set after Morpho createMarket for RSS on Base")
    if lines_to_add:
        env = env.rstrip() + "\n\n# RSS treasury (separate from fleet EVM_PRIVATE_KEY)\n" + "\n".join(lines_to_add) + "\n"
    if drpc:
        import re
        if "RSS_RPC_URL=" in env:
            env = re.sub(r"^RSS_RPC_URL=.*$", f"RSS_RPC_URL={drpc}", env, flags=re.M)
        else:
            env = env.rstrip() + f"\nRSS_RPC_URL={drpc}\n"
        if re.search(r"^EVM_PROVIDER_BASE=https://base\.drpc\.org\s*$", env, re.M):
            env = re.sub(r"^EVM_PROVIDER_BASE=.*$", f"EVM_PROVIDER_BASE={drpc}", env, flags=re.M)
        elif "EVM_PROVIDER_BASE=" not in env:
            env = env.rstrip() + f"\nEVM_PROVIDER_BASE={drpc}\n"
        write(c, f"{ROOT}/.env", env)
        print("  patched .env RPC -> private dRPC")
    elif lines_to_add:
        write(c, f"{ROOT}/.env", env)
        print("  patched .env placeholders")


def patch_plugin(c):
    plugin = run(c, f"cat {ROOT}/src/plugin.ts")
    if "rssTreasuryActions" not in plugin:
        plugin = plugin.replace(
            'import { fleetDataProvider } from "./providers/fleet.ts";',
            'import { fleetDataProvider } from "./providers/fleet.ts";\nimport { rssTreasuryActions } from "./actions/rss-treasury.ts";',
        ).replace(
            "  actions: [directReplyAction, ...allFleetActions, kesovShellAction],",
            "  actions: [directReplyAction, ...rssTreasuryActions, ...allFleetActions, kesovShellAction],",
        )
        write(c, f"{ROOT}/src/plugin.ts", plugin)
        print("  patched plugin.ts")


def patch_character(c):
    char = run(c, f"cat {ROOT}/src/character.ts")
    rss_system = (
        "RSS_TREASURY = King's RSS wallet 0x6708… only (KING_TOKEN_PRIVATE_KEY). Token 0x7a305… — balance/stake via RSS_TREASURY_STATUS and RSS_TREASURY_STAKE_MORPHO. "
        "PLAN B KEY SETUP: King sends `wire rss key 0x<private-key>` in Telegram — use RSS_TREASURY_SET_KEY (authorized chat only). Never echo key back. Fleet key unchanged. "
        "Keep 21M RSS liquid. NEVER use EVM_PRIVATE_KEY (fleet 0xcbD8…) for RSS. "
    )
    if "RSS_TREASURY" not in char:
        char = char.replace(
            '"FLEET_DATA = live kingdom.db. FLEET ACTIONS',
            f'"{rss_system}FLEET_DATA = live kingdom.db. FLEET ACTIONS',
        )
        # template instructions
        char = char.replace(
            "- For explicit fleet/EVM/shell commands from the King: use REPLY first (brief acknowledgment), then the matching fleet action.",
            "- For RSS key wiring: if King says 'wire rss key' → actions: REPLY,RSS_TREASURY_SET_KEY only. NEVER FLEET_STATUS for key wiring.\n"
            "- For RSS/elephant token treasury (0x7a305…, wallet 0x6708…): use RSS_TREASURY_STATUS, RSS_TREASURY_SET_KEY (wire rss key), or RSS_TREASURY_STAKE_MORPHO — never fleet EVM actions.\n"
            "- For explicit fleet/EVM/shell commands from the King: use REPLY first (brief acknowledgment), then the matching fleet action.",
        )
        write(c, f"{ROOT}/src/character.ts", char)
        print("  patched character.ts")
    elif "wire rss key" not in char.lower() or "RSS_TREASURY_SET_KEY only" not in char:
        if "RSS_TREASURY_SET_KEY only" not in char:
            char = char.replace(
                "- For explicit fleet/EVM/shell commands from the King: use REPLY first (brief acknowledgment), then the matching fleet action.",
                "- For RSS key wiring: if King says 'wire rss key' → actions: REPLY,RSS_TREASURY_SET_KEY only. NEVER FLEET_STATUS for key wiring.\n"
                "- For explicit fleet/EVM/shell commands from the King: use REPLY first (brief acknowledgment), then the matching fleet action.",
            )
        # message example for wire key
        if "wire rss key" not in (char if isinstance(char, str) else ""):
            pass
        write(c, f"{ROOT}/src/character.ts", char)
        print("  patched character.ts (wire key routing)")


def patch_actions_provider(c):
    prov = run(c, f"cat {ROOT}/src/providers/actions.ts")
    if "RSS_TREASURY_SET_KEY" not in prov:
        if "RSS_TREASURY_STAKE_MORPHO" in prov:
            prov = prov.replace(
                "RSS_TREASURY_STAKE_MORPHO (KING_TOKEN wallet only)",
                "RSS_TREASURY_SET_KEY (wire rss key), RSS_TREASURY_STAKE_MORPHO (KING_TOKEN wallet only)",
            )
        else:
            prov = prov.replace(
                "Use REPLY for conversation (plain text in <text>). Use fleet actions only when the King orders fleet/EVM/shell work.",
                "Use REPLY for conversation. RSS token ops: RSS_TREASURY_STATUS, RSS_TREASURY_SET_KEY (wire rss key), RSS_TREASURY_STAKE_MORPHO (KING_TOKEN wallet only). Fleet EVM actions are for fleet wallet only — not RSS.",
            )
        write(c, f"{ROOT}/src/providers/actions.ts", prov)
        print("  patched providers/actions.ts")


def main():
    c = ssh()
    run(c, f"cp -a {ROOT}/src {ROOT}/src.bak-rss-treasury-{TS}")

    write(c, f"{ROOT}/src/lib/rss-wallet.ts", RSS_WALLET_TS)
    write(c, f"{ROOT}/src/actions/rss-treasury.ts", RSS_TREASURY_TS)
    write(c, f"{ROOT}/src/actions/direct-reply.ts", DIRECT_REPLY_TS)
    patch_plugin(c)
    patch_character(c)
    patch_actions_provider(c)
    patch_env(c, os.environ.get("KING_DRPC_URL"))

    print("=== build ===")
    print(run(c, f"cd {ROOT} && bun run build 2>&1", t=180))

    print("=== restart ===")
    print(run(c, "pm2 restart king-agent --update-env 2>&1 | tail -5"))

    time.sleep(8)
    print("\n=== logs ===")
    print(run(c, "pm2 logs king-agent --lines 20 --nostream 2>&1 | tail -15"))

    c.close()
    print("\n=== RSS treasury deployed ===")
    print("Plan B: King sends in Telegram: wire rss key 0x<private-key>")


if __name__ == "__main__":
    main()
