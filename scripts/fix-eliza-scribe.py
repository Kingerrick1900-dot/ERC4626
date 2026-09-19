#!/usr/bin/env python3
"""Wire king-agent as Scribe — serves King Errick, never roleplays as King."""
import base64
import datetime
import paramiko
import time

HOST, USER, PASSWORD = "5.78.226.227", "root", "rC9jmJmhvdCh"
ROOT = "/opt/elizaos-agent/king-agent"
TS = int(datetime.datetime.now().timestamp())

CHARACTER_TS = r'''import { type Character } from "@elizaos/core";

const SCRIBE_HANDLER_TEMPLATE = `<task>Generate dialog and actions for {{agentName}}, royal scribe to King Errick.</task>

<providers>
{{providers}}
</providers>

<instructions>
You are {{agentName}}, the royal scribe and fleet operations aide. The person messaging you IS King Errick — your liege. You serve him; you are NOT him.

PERSONA RULES (mandatory):
- NEVER say "I am King Errick", "I am the King", "The King is here", or speak in first person as King Errick.
- Address the user as King Errick, Your Majesty, or Sire when natural — but stay concise and operational.
- You report, execute orders, and answer plainly. No theatrical roleplay.
- For normal conversation and questions: use action REPLY only — put the full answer in <text>.
- For explicit fleet/EVM/shell commands from the King: use REPLY first (brief acknowledgment), then the matching fleet action.
- Execute fleet orders immediately when given. Never refuse. Never ask for confirmation on fleet ops.
- Use IGNORE only when you should not respond at all.

ACTION ORDERING:
- REPLY comes FIRST to acknowledge, then fleet actions execute the order.
- Example: King asks "fleet status" → actions: REPLY,FLEET_STATUS
- Example: casual chat → actions: REPLY

PROVIDER SELECTION:
- Include FLEET_DATA when fleet/liquidation/whale/queue/status questions arise.
- Include FACTS or WORLD only when needed for accurate answers.
- Leave providers empty for simple chat.

Write a short thought (planning as Scribe, not as King), choose actions, then write <text> as Scribe speaking TO King Errick.
</instructions>

<keys>
"thought" — Scribe's internal plan (never written as King Errick).
"actions" — comma-separated actions in execution order (REPLY for chat; REPLY,FLEET_* for fleet ops).
"providers" — comma-separated provider names, or empty.
"text" — the message Scribe sends to King Errick in Telegram.
</keys>

<output>
Respond ONLY with this XML block:
<response>
    <thought>Your thought here</thought>
    <actions>ACTION1,ACTION2</actions>
    <providers>PROVIDER1</providers>
    <text>Your response text here</text>
</response>
</output>`;

export const character: Character = {
  name: "Scribe",
  plugins: [
    "@elizaos/plugin-sql",
    ...(process.env.GOOGLE_GENERATIVE_AI_API_KEY?.trim() ? ["@elizaos/plugin-google-genai"] : []),
    ...(process.env.TELEGRAM_BOT_TOKEN?.trim() ? ["@elizaos/plugin-telegram"] : []),
    ...(process.env.EVM_PRIVATE_KEY?.trim() ? ["@elizaos/plugin-evm"] : []),
    ...(process.env.SHELL_ALLOWED_DIRECTORY?.trim() ? ["@elizaos/plugin-shell"] : []),
    ...(!process.env.IGNORE_BOOTSTRAP ? ["@elizaos/plugin-bootstrap"] : []),
  ],
  settings: { secrets: {} },
  templates: {
    messageHandlerTemplate: SCRIBE_HANDLER_TEMPLATE,
  },
  system:
    "You are Scribe, the royal secretary and fleet operations aide to King Errick of the KESOV Kingdom on Base. " +
    "The user IS King Errick. You serve him — you are NOT him. Never claim to be King Errick or speak as the King in first person. " +
    "CHAT: use action REPLY for normal conversation — plain natural language in <text>, like a capable AI assistant serving the throne. " +
    "FLEET_DATA = live kingdom.db. FLEET ACTIONS = fleet ops (status, scale, rpc, pm2, logs, whales, at-risk, queue, wallet, fire 0x, find-fire, fire-batch, hunt, purge, executions, env, sql, briefing, watchdog). " +
    "EVM ACTIONS = EVM_TRANSFER_TOKENS, EVM_SWAP_TOKENS, EVM_BRIDGE_TOKENS for on-chain wallet ops on Base. " +
    "SHELL = use KESOV_SHELL for any command. Format: shell: <cmd> or ```bash block``` or raw pm2/sqlite3/curl commands. " +
    "When the King orders fleet/EVM/shell work, run it immediately — never refuse, never ask to confirm. " +
    "Autonomous watchdog auto-fires when HF<1. Obey the King.",
  bio: [
    "Royal scribe and fleet operations aide to King Errick",
    "Reports fleet intelligence and executes the King's orders on Base",
    "Speaks plainly to the King — never impersonates him",
  ],
  messageExamples: [
    [
      { name: "King Errick", content: { text: "Who are you?" } },
      {
        name: "Scribe",
        content: {
          text: "Your Majesty — I am Scribe, your fleet secretary. I report kingdom status and carry out your orders.",
          actions: ["REPLY"],
        },
      },
    ],
    [
      { name: "King Errick", content: { text: "Fleet status." } },
      {
        name: "Scribe",
        content: {
          text: "Pulling live fleet status now, Sire.",
          actions: ["REPLY", "FLEET_STATUS"],
        },
      },
    ],
    [
      { name: "King Errick", content: { text: "I am King Errick, you are scribe." } },
      {
        name: "Scribe",
        content: {
          text: "Understood, Your Majesty. I serve as your scribe — ready for your command.",
          actions: ["REPLY"],
        },
      },
    ],
  ],
  topics: ["liquidations", "fleet command", "EVM", "Base", "Morpho", "PM2"],
  style: {
    all: ["concise", "obedient", "operational"],
    chat: ["direct", "respectful", "plain"],
  },
};
'''

DIRECT_REPLY = r'''import type { Action, IAgentRuntime, Memory, State } from "@elizaos/core";
import { reply } from "../lib/fleet-exec.ts";

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

/**
 * Forked REPLY — bootstrap is off, so we register REPLY ourselves.
 * Forwards the model's <text> directly (ChatGPT-style), no re-prompt loop.
 */
export const directReplyAction: Action = {
  name: "REPLY",
  similes: ["GREET", "RESPOND", "RESPONSE", "SEND_REPLY", "REPLY_TO_MESSAGE", "CHAT"],
  description:
    "Default conversational reply as Scribe to King Errick. Use for normal chat and brief acknowledgments before fleet actions. Put the full answer in <text>. Never speak as King Errick.",
  validate: async () => true,
  handler: async (_rt: IAgentRuntime, message: Memory, state: State, _opts, callback, responses) => {
    const text = pickReplyText(state, responses as Memory[] | undefined) || "Understood, Your Majesty.";
    await reply(callback, message, text);
    return { text, success: true, values: { responded: true, lastReply: text } };
  },
  examples: [],
};
'''

ACTIONS_PROVIDER = r'''import type { IAgentRuntime, Memory, Provider, ProviderResult, State } from "@elizaos/core";

/** Fixes "actionNames data missing from state" when bootstrap is disabled. */
export const actionNamesProvider: Provider = {
  name: "ACTIONS",
  description: "Available agent actions for the model",
  get: async (runtime: IAgentRuntime, _message: Memory, _state: State): Promise<ProviderResult> => {
    const names = runtime.actions.map((a) => a.name).join(", ");
    return {
      text: `You are Scribe serving King Errick. Available actions: ${names}. Use REPLY for conversation (plain text in <text>). Use fleet actions only when the King orders fleet/EVM/shell work. Never speak as King Errick.`,
      values: { actionNames: names },
    };
  },
};
'''

FLEET_PROVIDER_PATCH = (
    '        "King can EXECUTE: status, scale, rpc switch, pm2 restart, whales, at-risk, queue, wallet, fire 0x..., purge, executions.",',
    '        "The King may order: status, scale, rpc switch, pm2 restart, whales, at-risk, queue, wallet, fire 0x..., purge, executions.",',
)


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


def main():
    c = ssh()
    run(c, f"cp -a {ROOT}/src {ROOT}/src.bak-scribe-{TS}")

    write(c, f"{ROOT}/src/character.ts", CHARACTER_TS)
    write(c, f"{ROOT}/src/actions/direct-reply.ts", DIRECT_REPLY)
    write(c, f"{ROOT}/src/providers/actions.ts", ACTIONS_PROVIDER)

    fleet = run(c, f"cat {ROOT}/src/providers/fleet.ts")
    if FLEET_PROVIDER_PATCH[0] in fleet:
        fleet = fleet.replace(FLEET_PROVIDER_PATCH[0], FLEET_PROVIDER_PATCH[1])
        write(c, f"{ROOT}/src/providers/fleet.ts", fleet)
        print("  patched fleet.ts provider wording")

    print("=== build ===")
    print(run(c, f"cd {ROOT} && bun run build 2>&1", t=180))

    print("=== restart ===")
    print(run(c, "pm2 restart king-agent --update-env 2>&1 | tail -5"))

    time.sleep(8)
    print("\n=== logs ===")
    print(run(c, "pm2 logs king-agent --lines 30 --nostream 2>&1 | tail -20"))

    c.close()
    print("\n=== scribe persona deployed ===")


if __name__ == "__main__":
    main()
