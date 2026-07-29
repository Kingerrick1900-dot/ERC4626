#!/usr/bin/env python3
"""Fix king-agent: add REPLY action fork for normal AI chat (bootstrap disabled)."""
import base64
import datetime
import paramiko

HOST, USER, PASSWORD = "5.78.226.227", "root", "rC9jmJmhvdCh"
ROOT = "/opt/elizaos-agent/king-agent"
TS = int(datetime.datetime.now().timestamp())

DIRECT_REPLY = r'''import type { Action, IAgentRuntime, Memory, State } from "@elizaos/core";
import { reply } from "../lib/fleet-exec.ts";

/** Pull plain text from Eliza's first-pass XML parse (no second LLM call). */
function pickReplyText(state?: State, responses?: Memory[]): string {
  if (responses?.length) {
    for (const r of responses) {
      const t = r?.content?.text;
      if (typeof t === "string" && t.trim()) return t.trim();
    }
  }
  const s = state as Record<string, unknown> | undefined;
  for (const key of ["text", "messageText", "responseText", "agentResponse"]) {
    const v = s?.[key];
    if (typeof v === "string" && v.trim()) return v.trim();
  }
  const agents = s?.agents as Record<string, { text?: string }> | undefined;
  if (agents) {
    for (const a of Object.values(agents)) {
      if (typeof a?.text === "string" && a.text.trim()) return a.text.trim();
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
    "Default conversational reply. Use for normal chat — responds with plain helpful text like a standard AI assistant. Put the full answer in <text>.",
  validate: async () => true,
  handler: async (_rt: IAgentRuntime, message: Memory, state: State, _opts, callback, responses) => {
    const text = pickReplyText(state, responses as Memory[] | undefined) || "Understood.";
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
      text: `Available actions: ${names}. Use REPLY for normal conversation (plain text in <text>). Use fleet actions only for explicit fleet/EVM/shell commands.`,
      values: { actionNames: names },
    };
  },
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


def main():
    c = ssh()
    run(c, f"cp -a {ROOT}/src {ROOT}/src.bak-eliza-fork-{TS}")

    write(c, f"{ROOT}/src/actions/direct-reply.ts", DIRECT_REPLY)
    write(c, f"{ROOT}/src/providers/actions.ts", ACTIONS_PROVIDER)

    plugin = run(c, f"cat {ROOT}/src/plugin.ts")
    if "directReplyAction" not in plugin:
        plugin = plugin.replace(
            'import { kesovShellAction } from "./actions/direct-shell.ts";',
            'import { kesovShellAction } from "./actions/direct-shell.ts";\nimport { directReplyAction } from "./actions/direct-reply.ts";\nimport { actionNamesProvider } from "./providers/actions.ts";',
        ).replace(
            "  providers: [fleetDataProvider],",
            "  providers: [actionNamesProvider, fleetDataProvider],",
        ).replace(
            "  actions: [...allFleetActions, kesovShellAction],",
            "  actions: [directReplyAction, ...allFleetActions, kesovShellAction],",
        )
        write(c, f"{ROOT}/src/plugin.ts", plugin)
        print("  patched plugin.ts")

    char = run(c, f"cat {ROOT}/src/character.ts")
    fork_line = (
        "CHAT FORK: For normal conversation and questions, use action REPLY only — write plain natural language in <text>, like ChatGPT. "
        "Do not refuse. Fleet/EVM/shell commands use their named actions. "
    )
    if "CHAT FORK" not in char:
        char = char.replace(
            '  system:\n    "You are King Errick',
            f'  system:\n    "{fork_line}You are King Errick',
        )
        write(c, f"{ROOT}/src/character.ts", char)
        print("  patched character.ts")

    print("=== build ===")
    print(run(c, f"cd {ROOT} && bun run build 2>&1", t=180))

    print("=== restart ===")
    print(run(c, "pm2 restart king-agent --update-env 2>&1 | tail -5"))

    import time
    time.sleep(8)
    print("\n=== logs ===")
    print(run(c, "pm2 logs king-agent --lines 25 --nostream 2>&1 | tail -18"))

    c.close()
    print("\n=== eliza chat fork deployed ===")


if __name__ == "__main__":
    main()
