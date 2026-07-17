#!/usr/bin/env node
/**
 * Morpho Desk Guardian — HF < floor → selfDeleverage toward target.
 * Env: RPC_URL, KING_TOKEN_PRIVATE_KEY, DESK, KING, HF_FLOOR, HF_TARGET, POLL_MS, DRY_RUN
 */
import {
  createPublicClient,
  createWalletClient,
  http,
  fallback,
  parseAbi,
  formatUnits,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";

const DESK = (process.env.DESK || "0x831b86E9AA185088CB095748bFBeF53F0D312472");
const KING = (process.env.KING || "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1");
const MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
const MARKET_ID =
  process.env.MORPHO_RSS_MARKET_ID ||
  "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794";
const POLL_MS = Number(process.env.POLL_MS || 20_000);
const DRY = process.env.DRY_RUN === "1";

const deskAbi = parseAbi([
  "function healthFactor(address user) view returns (uint256)",
  "function hfFloor() view returns (uint256)",
  "function hfTarget() view returns (uint256)",
  "function lltv() view returns (uint256)",
  "function oracle() view returns (address)",
  "function marketId() view returns (bytes32)",
  "function selfDeleverage(uint256 repayBorrowAssets)",
]);
const morphoAbi = parseAbi([
  "function position(bytes32 id, address user) view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral)",
  "function market(bytes32 id) view returns (uint128 totalSupplyAssets, uint128 totalSupplyShares, uint128 totalBorrowAssets, uint128 totalBorrowShares, uint128 lastUpdate, uint128 fee)",
]);
const oracleAbi = parseAbi(["function price() view returns (uint256)"]);

function rpcs() {
  const urls = [
    process.env.RSS_RPC_URL,
    process.env.RPC_URL,
    process.env.EVM_PROVIDER_BASE,
    "https://base.publicnode.com",
  ].filter(Boolean);
  return fallback(urls.map((u) => http(u)));
}

function log(...a) {
  console.log(new Date().toISOString(), "[morpho-guardian]", ...a);
}

async function computeRepay(publicClient, floor, target) {
  const hf = await publicClient.readContract({
    address: DESK,
    abi: deskAbi,
    functionName: "healthFactor",
    args: [KING],
  });
  if (hf >= floor) return { hf, repay: 0n };

  const [pos, mkt, lltv, oracle] = await Promise.all([
    publicClient.readContract({
      address: MORPHO,
      abi: morphoAbi,
      functionName: "position",
      args: [MARKET_ID, KING],
    }),
    publicClient.readContract({
      address: MORPHO,
      abi: morphoAbi,
      functionName: "market",
      args: [MARKET_ID],
    }),
    publicClient.readContract({ address: DESK, abi: deskAbi, functionName: "lltv" }),
    publicClient.readContract({ address: DESK, abi: deskAbi, functionName: "oracle" }),
  ]);
  const [, borrowShares, collateral] = pos;
  const [, , totalBorrowAssets, totalBorrowShares] = mkt;
  if (borrowShares === 0n || totalBorrowShares === 0n) return { hf, repay: 0n };

  const borrowAssets =
    (BigInt(borrowShares) * BigInt(totalBorrowAssets) + BigInt(totalBorrowShares) - 1n) /
    BigInt(totalBorrowShares);
  const px = await publicClient.readContract({
    address: oracle,
    abi: oracleAbi,
    functionName: "price",
  });
  const collValue = (BigInt(collateral) * px) / 10n ** 36n;
  const maxBorrow = (collValue * lltv) / 10n ** 18n;
  // newBorrow <= maxBorrow * 1e18 / target
  const maxDebtForTarget = (maxBorrow * 10n ** 18n) / target;
  if (borrowAssets <= maxDebtForTarget) return { hf, repay: 0n };
  let repay = borrowAssets - maxDebtForTarget;
  // leave dust buffer; never repay more than ~95% of book in one hit
  const cap = (borrowAssets * 95n) / 100n;
  if (repay > cap) repay = cap;
  // round up to 1 USDC unit at least
  if (repay > 0n && repay < 1_000_000n) repay = 1_000_000n;
  return { hf, repay, borrowAssets, maxBorrow };
}

async function tick(publicClient, walletClient) {
  const [floor, target] = await Promise.all([
    publicClient.readContract({ address: DESK, abi: deskAbi, functionName: "hfFloor" }),
    publicClient.readContract({ address: DESK, abi: deskAbi, functionName: "hfTarget" }),
  ]);
  const { hf, repay, borrowAssets } = await computeRepay(publicClient, floor, target);
  log(
    `HF=${formatUnits(hf, 18)} floor=${formatUnits(floor, 18)} target=${formatUnits(target, 18)}` +
      (repay > 0n ? ` → repay ${formatUnits(repay, 6)} USDC (debt≈${formatUnits(borrowAssets || 0n, 6)})` : " OK")
  );
  if (repay === 0n) return;
  if (DRY) {
    log("DRY_RUN — skip selfDeleverage");
    return;
  }
  const hash = await walletClient.writeContract({
    address: DESK,
    abi: deskAbi,
    functionName: "selfDeleverage",
    args: [repay],
  });
  log("selfDeleverage tx", hash);
  await publicClient.waitForTransactionReceipt({ hash });
  const hf2 = await publicClient.readContract({
    address: DESK,
    abi: deskAbi,
    functionName: "healthFactor",
    args: [KING],
  });
  log("post-HF", formatUnits(hf2, 18));
}

async function main() {
  const pk = process.env.KING_TOKEN_PRIVATE_KEY?.trim();
  if (!pk) throw new Error("KING_TOKEN_PRIVATE_KEY required");
  const key = (pk.startsWith("0x") ? pk : `0x${pk}`);
  const account = privateKeyToAccount(key);
  if (account.address.toLowerCase() !== KING.toLowerCase()) {
    throw new Error(`Key signs ${account.address}, expected ${KING}`);
  }
  const transport = rpcs();
  const publicClient = createPublicClient({ chain: base, transport });
  const walletClient = createWalletClient({ chain: base, transport, account });
  log("watching desk", DESK, "dry=", DRY);
  for (;;) {
    try {
      await tick(publicClient, walletClient);
    } catch (e) {
      log("error", String(e?.shortMessage || e?.message || e));
    }
    await new Promise((r) => setTimeout(r, POLL_MS));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
