#!/usr/bin/env node
/**
 * Quiet scaling engine — deepen self-lend in small steps without marketing.
 * ONLY runs when QUIET_SCALE_ENABLED=1.
 * Caps: min HF, max step USDC, keep liquid RSS reserve.
 */
import {
  createPublicClient,
  createWalletClient,
  http,
  fallback,
  parseAbi,
  formatUnits,
  erc20Abi,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";

const DESK = process.env.DESK || "0x831b86E9AA185088CB095748bFBeF53F0D312472";
const KING = process.env.KING || "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1";
const RSS = process.env.RSS_TOKEN_ADDRESS || "0x7a305D07B537359cf468eAea9bb176E5308bC337";
const MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
const ENABLED = process.env.QUIET_SCALE_ENABLED === "1";
const POLL_MS = Number(process.env.SCALE_POLL_MS || 3600_000); // hourly default
const MIN_HF = BigInt(process.env.SCALE_MIN_HF || "1400000000000000000"); // 1.40
const STEP_USDC = BigInt(process.env.SCALE_STEP_USDC || "25000000000"); // $25k
const LIQUID_RSS = BigInt(process.env.RSS_LIQUID_RESERVE || "1000000") * 10n ** 18n;
const DRY = process.env.DRY_RUN === "1";

const deskAbi = parseAbi([
  "function healthFactor(address user) view returns (uint256)",
  "function openSelfLend(uint256 rssAmount, uint256 flashUsdc)",
  "function lltv() view returns (uint256)",
  "function oracle() view returns (address)",
]);
const oracleAbi = parseAbi(["function price() view returns (uint256)"]);
const morphoAuthAbi = parseAbi([
  "function setAuthorization(address authorized, bool newIsAuthorized)",
  "function isAuthorized(address user, address authorized) view returns (bool)",
]);

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
  console.log(new Date().toISOString(), "[quiet-scaler]", ...a);
}

async function tick(publicClient, walletClient, account) {
  if (!ENABLED) {
    log("disabled (set QUIET_SCALE_ENABLED=1)");
    return;
  }
  const hf = await publicClient.readContract({
    address: DESK,
    abi: deskAbi,
    functionName: "healthFactor",
    args: [KING],
  });
  if (hf < MIN_HF) {
    log(`HF ${formatUnits(hf, 18)} < min ${formatUnits(MIN_HF, 18)} — skip`);
    return;
  }
  const bal = await publicClient.readContract({
    address: RSS,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [KING],
  });
  if (bal <= LIQUID_RSS) {
    log("no RSS above liquid reserve — skip");
    return;
  }
  const [lltv, oracle] = await Promise.all([
    publicClient.readContract({ address: DESK, abi: deskAbi, functionName: "lltv" }),
    publicClient.readContract({ address: DESK, abi: deskAbi, functionName: "oracle" }),
  ]);
  const px = await publicClient.readContract({
    address: oracle,
    abi: oracleAbi,
    functionName: "price",
  });
  // Choose flash ≤ STEP_USDC and HF buffer: debt = ~50% of max at oracle
  let flash = STEP_USDC;
  // rss needed so maxBorrow >= flash * buffer; use coll such that (coll*px/1e36)*lltv >= flash * 1.5
  const needCollValue = (flash * 15n * 10n ** 18n) / (lltv * 10n);
  // collValue = rss * px / 1e36 → rss = collValue * 1e36 / px
  let rssAmt = (needCollValue * 10n ** 36n) / px;
  const usable = bal - LIQUID_RSS;
  if (rssAmt > usable) {
    rssAmt = usable;
    const collValue = (rssAmt * px) / 10n ** 36n;
    const maxBorrow = (collValue * lltv) / 10n ** 18n;
    flash = (maxBorrow * 50n) / 100n; // 50% of max → HF≈2.0 path under util
    if (flash < 1_000_000n) {
      log("step too small after reserve — skip");
      return;
    }
  }
  log(
    `scale step rss=${formatUnits(rssAmt, 18)} flashUsdc=${formatUnits(flash, 6)} HF=${formatUnits(hf, 18)}`
  );
  if (DRY) {
    log("DRY_RUN — skip");
    return;
  }
  const auth = await publicClient.readContract({
    address: MORPHO,
    abi: morphoAuthAbi,
    functionName: "isAuthorized",
    args: [KING, DESK],
  });
  if (!auth) {
    await walletClient.writeContract({
      address: MORPHO,
      abi: morphoAuthAbi,
      functionName: "setAuthorization",
      args: [DESK, true],
    });
  }
  await walletClient.writeContract({
    address: RSS,
    abi: erc20Abi,
    functionName: "approve",
    args: [DESK, rssAmt],
    gas: 500000n,
  });
  const hash = await walletClient.writeContract({
    address: DESK,
    abi: deskAbi,
    functionName: "openSelfLend",
    args: [rssAmt, flash],
    gas: 2500000n,
  });
  log("openSelfLend", hash);
  await publicClient.waitForTransactionReceipt({ hash });
}

async function main() {
  const pk = process.env.KING_TOKEN_PRIVATE_KEY?.trim();
  if (!pk) throw new Error("KING_TOKEN_PRIVATE_KEY required");
  const key = (pk.startsWith("0x") ? pk : `0x${pk}`);
  const account = privateKeyToAccount(key);
  const transport = rpcs();
  const publicClient = createPublicClient({ chain: base, transport });
  const walletClient = createWalletClient({ chain: base, transport, account });
  log("quiet scaler boot enabled=", ENABLED, "dry=", DRY);
  for (;;) {
    try {
      await tick(publicClient, walletClient, account);
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
