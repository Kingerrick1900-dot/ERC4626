"""Deploy POD_STATUS into king-agent on VPS — reports live King Pod numbers."""
import datetime
import paramiko

HOST, USER, PASSWORD = "5.78.226.227", "root", "rC9jmJmhvdCh"
ROOT = "/opt/elizaos-agent/king-agent"
TS = int(datetime.datetime.now().timestamp())

POD_SNIPPET = r'''
// --- POD_STATUS (injected) ---
import { createPublicClient, http, formatUnits, fallback } from "viem";
import { base } from "viem/chains";

const POD_ADDRS = {
  pod: "0x4aa72a111e9E78753F7f3217edfD9177aA0B2dcc",
  market: "0x50a61ca6b06563f1a44f7f2186a325b5301e2578",
  pair: "0x56ebfc0af28e1a9d8e6f9d0f3262ff1ad1a78f8c",
  sUsdc: "0x4af86ac17eb6f12588b2f3b70969f304933d1021",
  king: "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1",
  usdc: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  rss: "0x7a305D07B537359cf468eAea9bb176E5308bC337",
  bootstrapTx: "0x09c2e084609e76d0129fc1e8a77e8b97877904e194c2112262d939c499ae386e",
} as const;

const marketAbi = [
  { name: "collateralLp", type: "function", stateMutability: "view", inputs: [{ type: "address" }], outputs: [{ type: "uint256" }] },
  { name: "debtUsdc", type: "function", stateMutability: "view", inputs: [{ type: "address" }], outputs: [{ type: "uint256" }] },
  { name: "maxBorrow", type: "function", stateMutability: "view", inputs: [{ type: "address" }], outputs: [{ type: "uint256" }] },
  { name: "healthFactor", type: "function", stateMutability: "view", inputs: [{ type: "address" }], outputs: [{ type: "uint256" }] },
] as const;

export const podStatusAction: Action = {
  name: "POD_STATUS",
  similes: ["KING_POD_STATUS", "POD_TREASURY"],
  description: "King Pod Option A live status on Base: LP collateral, debt, maxBorrow, idle USDC, liquid RSS.",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return ["pod status", "king pod", "pod treasury", "rss pod"].some((k) => t.includes(k));
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    try {
      const rpc = process.env.RSS_RPC_URL || process.env.EVM_PROVIDER_BASE || "https://base.publicnode.com";
      const client = createPublicClient({ chain: base, transport: fallback([http(rpc), http("https://base.publicnode.com")]) });
      const k = POD_ADDRS.king;
      const [coll, debt, maxB, hf, idle, rssBal] = await Promise.all([
        client.readContract({ address: POD_ADDRS.market, abi: marketAbi, functionName: "collateralLp", args: [k] }),
        client.readContract({ address: POD_ADDRS.market, abi: marketAbi, functionName: "debtUsdc", args: [k] }),
        client.readContract({ address: POD_ADDRS.market, abi: marketAbi, functionName: "maxBorrow", args: [k] }),
        client.readContract({ address: POD_ADDRS.market, abi: marketAbi, functionName: "healthFactor", args: [k] }),
        client.readContract({ address: POD_ADDRS.usdc, abi: erc20Abi, functionName: "balanceOf", args: [POD_ADDRS.sUsdc] }),
        client.readContract({ address: POD_ADDRS.rss, abi: erc20Abi, functionName: "balanceOf", args: [k] }),
      ]);
      const lines = [
        "**King Pod (Base) — LIVE**",
        `Pod: \`${POD_ADDRS.pod}\``,
        `Debt: **${formatUnits(debt, 6)} USDC**`,
        `Max borrow capacity: **${formatUnits(maxB, 6)} USDC**`,
        `Idle USDC in vault (lendable): **${formatUnits(idle, 6)} USDC**`,
        `Liquid RSS (wallet): **${formatUnits(rssBal, 18)}**`,
        `Health factor: **${hf === (2n ** 256n - 1n) ? "∞" : formatUnits(hf, 18)}**`,
        `LP collateral units: \`${coll.toString()}\``,
        `Bootstrap: \`${POD_ADDRS.bootstrapTx}\``,
        idle === 0n
          ? "Phase C blocked: need external USDC deposits into sUSDC before borrow/12% cut."
          : "Idle USDC available — King may borrow (Phase C / 12% team cut).",
      ];
      await reply(callback, message, lines.join("\\n"));
    } catch (err) {
      await reply(callback, message, `Pod status error: ${String(err)}`);
    }
  },
  examples: [],
};
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASSWORD, timeout=30)
    sftp = ssh.open_sftp()

    # Patch rss-treasury.ts to append pod status if missing
    path = f"{ROOT}/src/actions/rss-treasury.ts"
    with sftp.open(path, "r") as f:
        src = f.read().decode()
    if "POD_STATUS" in src:
        print("POD_STATUS already present")
    else:
        bak = f"{path}.bak-pod-{TS}"
        with sftp.open(bak, "w") as f:
            f.write(src)
        # Inject import erc20Abi if needed
        if "erc20Abi" not in src:
            src = src.replace(
                'import { formatUnits } from "viem";',
                'import { formatUnits, erc20Abi } from "viem";',
            )
        # Append action before export array
        if "export const rssTreasuryActions" in src:
            src = src.replace(
                "export const rssTreasuryActions",
                POD_SNIPPET + "\n\nexport const rssTreasuryActions",
            )
            src = src.replace(
                "rssTreasuryActions: Action[] = [",
                "rssTreasuryActions: Action[] = [",
            )
            # add to array
            if "rssTreasurySetKeyAction," in src or "rssTreasurySetKeyAction" in src:
                src = src.replace(
                    "rssTreasurySetKeyAction,",
                    "rssTreasurySetKeyAction,\n  podStatusAction,",
                )
                if "podStatusAction," not in src:
                    src = src.replace(
                        "rssTreasurySetKeyAction",
                        "rssTreasurySetKeyAction,\n  podStatusAction",
                    )
        with sftp.open(path, "w") as f:
            f.write(src)
        print("patched rss-treasury.ts")

    # character hint
    cpath = f"{ROOT}/src/character.ts"
    with sftp.open(cpath, "r") as f:
        char = f.read().decode()
    if "pod status" not in char.lower():
        needle = "RSS_TREASURY_STAKE_MORPHO"
        if needle in char:
            char = char.replace(
                needle,
                needle + ", POD_STATUS (King Pod live on Base)",
                1,
            )
        with sftp.open(cpath, "w") as f:
            f.write(char)
        print("patched character")

    _, out, err = ssh.exec_command(f"cd {ROOT} && pm2 restart king-agent --update-env", timeout=40)
    print(out.read().decode()[-1500:] or err.read().decode()[-800:])
    sftp.close()
    ssh.close()
    print("done")

if __name__ == "__main__":
    main()
