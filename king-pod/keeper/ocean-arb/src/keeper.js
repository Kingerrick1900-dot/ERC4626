/**
 * OceanArb Keeper Bot
 * Polls Base / Polygon / Scroll OceanArb sleeves.
 * When quoted edge ≥ MIN_EDGE_BPS (default 20 = 0.2%), calls rotate().
 * Optional pushProfit when excess > PUSH_MIN.
 *
 * Env:
 *   PRIVATE_KEY          — HOT / ops key (one wallet)
 *   OCEAN_BASE           — OceanArb address on Base
 *   OCEAN_POLYGON        — OceanArb on Polygon (optional)
 *   OCEAN_SCROLL         — OceanArb on Scroll (optional)
 *   RPC_BASE / RPC_POLYGON / RPC_SCROLL
 *   ROUTE_DATA_BASE      — hex bytes for router (default 0x)
 *   MIN_EDGE_BPS         — default 20
 *   ROTATE_USDC          — raw 6dp amount per rotate (default 1000000000 = $1k dry size)
 *   PUSH_MIN             — min excess USDC to pushProfit (default 0 = skip)
 *   POLL_MS              — default 15000
 *   DRY_RUN=1            — quote/log only
 */
import {
  createPublicClient,
  createWalletClient,
  http,
  parseAbi,
  formatUnits,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base, polygon, scroll } from "viem/chains";

const ABI = parseAbi([
  "function armed() view returns (bool)",
  "function liquid() view returns (uint256)",
  "function minEdgeBps() view returns (uint256)",
  "function maxRotate() view returns (uint256)",
  "function totalProfit() view returns (uint256)",
  "function rotations() view returns (uint256)",
  "function totalSeeded() view returns (uint256)",
  "function rotate(uint256 usdcIn, bytes routeData) returns (uint256 profit)",
  "function pushProfit(uint256 amt)",
]);

const CHAINS = [
  {
    name: "base",
    chain: base,
    rpc: process.env.RPC_BASE || "https://mainnet.base.org",
    ocean: process.env.OCEAN_BASE,
    routeData: process.env.ROUTE_DATA_BASE || "0x",
  },
  {
    name: "polygon",
    chain: polygon,
    rpc: process.env.RPC_POLYGON || "https://polygon-rpc.com",
    ocean: process.env.OCEAN_POLYGON,
    routeData: process.env.ROUTE_DATA_POLYGON || "0x",
  },
  {
    name: "scroll",
    chain: scroll,
    rpc: process.env.RPC_SCROLL || "https://rpc.scroll.io",
    ocean: process.env.OCEAN_SCROLL,
    routeData: process.env.ROUTE_DATA_SCROLL || "0x",
  },
].filter((c) => c.ocean && /^0x[0-9a-fA-F]{40}$/.test(c.ocean));

const MIN_EDGE_BPS = BigInt(process.env.MIN_EDGE_BPS || "20");
const ROTATE_USDC = BigInt(process.env.ROTATE_USDC || "1000000000"); // $1,000
const PUSH_MIN = BigInt(process.env.PUSH_MIN || "0");
const POLL_MS = Number(process.env.POLL_MS || "15000");
const DRY = process.env.DRY_RUN === "1";

function requireKey() {
  const raw = process.env.PRIVATE_KEY || process.env.HOT_KEY;
  if (!raw) throw new Error("PRIVATE_KEY or HOT_KEY required");
  const hex = raw.startsWith("0x") ? raw : `0x${raw}`;
  return privateKeyToAccount(hex);
}

async function tick(account) {
  for (const cfg of CHAINS) {
    const publicClient = createPublicClient({
      chain: cfg.chain,
      transport: http(cfg.rpc),
    });
    const walletClient = createWalletClient({
      account,
      chain: cfg.chain,
      transport: http(cfg.rpc),
    });

    try {
      const [armed, liquid, minEdge, maxRot, seeded, profit, rotations] =
        await Promise.all([
          publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "armed",
          }),
          publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "liquid",
          }),
          publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "minEdgeBps",
          }),
          publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "maxRotate",
          }),
          publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "totalSeeded",
          }),
          publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "totalProfit",
          }),
          publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "rotations",
          }),
        ]);

      const edge = minEdge > MIN_EDGE_BPS ? minEdge : MIN_EDGE_BPS;
      let usdcIn = ROTATE_USDC;
      if (usdcIn > maxRot) usdcIn = maxRot;
      if (usdcIn > liquid) usdcIn = liquid;

      console.log(
        JSON.stringify({
          ts: new Date().toISOString(),
          chain: cfg.name,
          ocean: cfg.ocean,
          armed,
          liquid: formatUnits(liquid, 6),
          seeded: formatUnits(seeded, 6),
          profit: formatUnits(profit, 6),
          rotations: rotations.toString(),
          edgeBps: edge.toString(),
          usdcIn: formatUnits(usdcIn, 6),
          dry: DRY,
        })
      );

      if (!armed || usdcIn === 0n) continue;

      if (!DRY) {
        const hash = await walletClient.writeContract({
          address: cfg.ocean,
          abi: ABI,
          functionName: "rotate",
          args: [usdcIn, cfg.routeData],
        });
        console.log(JSON.stringify({ chain: cfg.name, rotateTx: hash }));

        const excess = liquid > seeded ? liquid - seeded : 0n;
        if (PUSH_MIN > 0n && excess >= PUSH_MIN) {
          const pushHash = await walletClient.writeContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "pushProfit",
            args: [0n],
          });
          console.log(JSON.stringify({ chain: cfg.name, pushTx: pushHash }));
        }
      }
    } catch (err) {
      console.error(
        JSON.stringify({
          chain: cfg.name,
          error: String(err?.shortMessage || err?.message || err),
        })
      );
    }
  }
}

async function main() {
  if (CHAINS.length === 0) {
    console.error(
      "No OceanArb addresses. Set OCEAN_BASE / OCEAN_POLYGON / OCEAN_SCROLL."
    );
    process.exit(1);
  }
  const account = DRY && !process.env.PRIVATE_KEY && !process.env.HOT_KEY
    ? null
    : requireKey();
  console.log(
    JSON.stringify({
      event: "keeper_start",
      chains: CHAINS.map((c) => c.name),
      pollMs: POLL_MS,
      dry: DRY,
      account: account?.address ?? null,
    })
  );

  // dry without key: read-only
  for (;;) {
    if (DRY && !account) {
      for (const cfg of CHAINS) {
        const publicClient = createPublicClient({
          chain: cfg.chain,
          transport: http(cfg.rpc),
        });
        try {
          const liquid = await publicClient.readContract({
            address: cfg.ocean,
            abi: ABI,
            functionName: "liquid",
          });
          console.log(
            JSON.stringify({
              chain: cfg.name,
              liquid: formatUnits(liquid, 6),
              mode: "readonly",
            })
          );
        } catch (e) {
          console.error(JSON.stringify({ chain: cfg.name, error: String(e) }));
        }
      }
    } else {
      await tick(account);
    }
    await new Promise((r) => setTimeout(r, POLL_MS));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
