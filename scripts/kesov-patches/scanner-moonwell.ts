import { ethers } from "ethers";
import * as fs from "fs";
import { upsertLiquidationQueue, logEvent } from "./db";
import { ADDRESSES } from "./addresses";
import { MULTICALL3_ABI } from "./abis";

const PERSIST_FILE   = "/opt/kesov-kingdom/moonwell_state.json";
const SCAN_INTERVAL  = parseInt(process.env.SCAN_INTERVAL_MS || "90000", 10);
const DISCOVER_CHUNK = 5_000;
const HF_THRESHOLD   = 1.15;
const MIN_DEBT_USD   = 200;
const MC_BATCH       = 300;
const DETAIL_BATCH   = 20;
const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

const COMPTROLLER   = "0xfBb21d0380beE3312B33c4353c8936a0F13EF26C";
const ORACLE_ADDR   = "0xEC942bE8A8114bFD0396A5052c36027f2cA6a9d0";
const DEPLOY_BLOCK  = 3_800_000;
const LIQ_INCENTIVE = 1.1;
const CLOSE_FACTOR  = 0.5;

const COMPTROLLER_ABI = [
  "function getAllMarkets() external view returns (address[])",
  "function getAccountLiquidity(address account) external view returns (uint256 err, uint256 liquidity, uint256 shortfall)",
  "function markets(address mToken) external view returns (bool isListed, uint256 collateralFactorMantissa)",
];
const MTOKEN_ABI = [
  "event Borrow(address indexed borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows)",
  "function borrowBalanceStored(address account) external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)",
  "function exchangeRateStored() external view returns (uint256)",
  "function underlying() external view returns (address)",
  "function symbol() external view returns (string)",
];
const ORACLE_ABI  = ["function getUnderlyingPrice(address mToken) external view returns (uint256)"];
const ERC20_ABI   = ["function decimals() external view returns (uint8)", "function symbol() external view returns (string)"];

interface MktInfo {
  mToken: string; symbol: string; underlying: string;
  uSymbol: string; uDecimals: number; colFactor: number;
}
interface MoonwellState { borrowers: string[]; lastBlock: number; }
interface MktPosition { mToken: string; uSymbol: string; underlying: string; borrowUsd: number; colUsd: number; }

function loadState(): MoonwellState {
  try { return JSON.parse(fs.readFileSync(PERSIST_FILE, "utf8")); }
  catch { return { borrowers: [], lastBlock: DEPLOY_BLOCK }; }
}
function saveState(s: MoonwellState): void { fs.writeFileSync(PERSIST_FILE, JSON.stringify(s)); }

async function loadMarkets(provider: ethers.providers.JsonRpcProvider): Promise<MktInfo[]> {
  const comp = new ethers.Contract(COMPTROLLER, COMPTROLLER_ABI, provider);
  const allMarkets: string[] = await comp.getAllMarkets();
  const infos: MktInfo[] = [];
  for (const mToken of allMarkets) {
    try {
      const mt = new ethers.Contract(mToken, MTOKEN_ABI, provider);
      const [mSym, underlying, [, colFactorBN]] = await Promise.all([
        mt.symbol(),
        mt.underlying().catch(() => ethers.constants.AddressZero),
        comp.markets(mToken),
      ]);
      const colFactor = parseFloat(ethers.utils.formatUnits(colFactorBN, 18));
      let uSymbol = "ETH", uDecimals = 18;
      if (underlying !== ethers.constants.AddressZero) {
        const erc20 = new ethers.Contract(underlying, ERC20_ABI, provider);
        const _ud = await Promise.all([erc20.symbol(), erc20.decimals()]);
        uSymbol = _ud[0] as string;
        uDecimals = _ud[1] as number;
      }
      infos.push({ mToken, symbol: mSym, underlying, uSymbol, uDecimals, colFactor });
    } catch { /* skip */ }
  }
  console.log(`[moonwell] loaded ${infos.length} markets: ${infos.map(m => m.uSymbol).join(", ")}`);
  return infos;
}

async function discoverBorrowers(
  provider: ethers.providers.JsonRpcProvider,
  markets: MktInfo[],
  state: MoonwellState
): Promise<void> {
  const latest    = await provider.getBlockNumber();
  const fromBlock = state.lastBlock + 1;
  if (fromBlock >= latest) return;
  const borrowerSet = new Set(state.borrowers);
  const ifaceMt     = new ethers.utils.Interface(MTOKEN_ABI);
  const borrowTopic = ifaceMt.getEventTopic("Borrow");
  let discovered = 0;
  for (let from = fromBlock; from < latest; from += DISCOVER_CHUNK) {
    const to = Math.min(from + DISCOVER_CHUNK - 1, latest);
    try {
      const logs = await provider.getLogs({ address: markets.map(m => m.mToken) as any, topics: [borrowTopic], fromBlock: from, toBlock: to });
      for (const log of logs) {
        const decoded = ifaceMt.parseLog(log);
        const borrower = decoded.args.borrower;
        if (borrower && !borrowerSet.has(borrower)) { borrowerSet.add(borrower); discovered++; }
      }
    } catch { await sleep(300); }
    await sleep(50);
    if ((from - state.lastBlock) % 50000 < DISCOVER_CHUNK) {
      const pct = Math.round((from - DEPLOY_BLOCK) / (latest - DEPLOY_BLOCK) * 100);
      console.log(`[moonwell] discovery ${pct}% blk=${from} borrowers=${borrowerSet.size}`);
      state.borrowers = Array.from(borrowerSet);
      state.lastBlock = from;
      saveState(state);
    }
  }
  state.borrowers = Array.from(borrowerSet);
  state.lastBlock  = latest;
  if (discovered > 0) console.log(`[moonwell] +${discovered} new borrowers (total ${state.borrowers.length})`);
}

async function screenBorrowers(
  provider: ethers.providers.JsonRpcProvider,
  borrowers: string[],
): Promise<string[]> {
  const mc  = new ethers.Contract(ADDRESSES.MULTICALL3, MULTICALL3_ABI, provider);
  const ifc = new ethers.utils.Interface(COMPTROLLER_ABI);
  const atRisk: string[] = [];
  for (let i = 0; i < borrowers.length; i += MC_BATCH) {
    const slice = borrowers.slice(i, i + MC_BATCH);
    const calls = slice.map(user => ({ target: COMPTROLLER, allowFailure: true, callData: ifc.encodeFunctionData("getAccountLiquidity", [user]) }));
    try {
      const results = await mc.callStatic.aggregate3(calls);
      for (let j = 0; j < slice.length; j++) {
        const res = results[j];
        if (!res.success) continue;
        try {
          const [err, liquidity, shortfall] = ifc.decodeFunctionResult("getAccountLiquidity", res.returnData);
          if (err.toNumber() !== 0) continue;
          const liqUsd = parseFloat(ethers.utils.formatUnits(liquidity, 18));
          const sfUsd  = parseFloat(ethers.utils.formatUnits(shortfall, 18));
          if (sfUsd > 0 || liqUsd < 1000) atRisk.push(slice[j]);
        } catch { /* skip */ }
      }
    } catch { await sleep(200); }
    await sleep(60);
  }
  return atRisk;
}

async function enrichUser(
  provider: ethers.providers.JsonRpcProvider,
  user: string,
  markets: MktInfo[],
  oracle: ethers.Contract,
  block: number,
): Promise<void> {
  const ts = Math.floor(Date.now() / 1000);
  let totalBorrowUsd = 0, totalColUsd = 0, totalWeightedColUsd = 0;
  const positions: MktPosition[] = [];
  for (const mkt of markets) {
    try {
      const mt = new ethers.Contract(mkt.mToken, MTOKEN_ABI, provider);
      const [borrowBal, colBal, exRate, priceRaw] = await Promise.all([
        mt.borrowBalanceStored(user),
        mt.balanceOf(user),
        mt.exchangeRateStored(),
        oracle.getUnderlyingPrice(mkt.mToken),
      ]);
      const price         = parseFloat(ethers.utils.formatUnits(priceRaw, 36 - mkt.uDecimals));
      const borrowAmt     = parseFloat(ethers.utils.formatUnits(borrowBal, mkt.uDecimals));
      const borrowUsd     = borrowAmt * price;
      const exRateFloat   = parseFloat(ethers.utils.formatUnits(exRate, 10 + mkt.uDecimals));
      const colMTokens    = parseFloat(ethers.utils.formatUnits(colBal, 8));
      const colUsd        = colMTokens * exRateFloat * price;
      totalBorrowUsd      += borrowUsd;
      totalColUsd         += colUsd;
      totalWeightedColUsd += colUsd * mkt.colFactor;
      if (borrowUsd > 1 || colUsd > 1) positions.push({ mToken: mkt.mToken, uSymbol: mkt.uSymbol, underlying: mkt.underlying, borrowUsd, colUsd });
    } catch { /* skip */ }
  }
  if (totalBorrowUsd < MIN_DEBT_USD) return;
  const hf = totalBorrowUsd > 0 ? totalWeightedColUsd / totalBorrowUsd : 999;
  if (hf > HF_THRESHOLD) return;
  const debtMkt = positions.filter(p => p.borrowUsd > 0).sort((a, b) => b.borrowUsd - a.borrowUsd)[0];
  const colMkt  = positions.filter(p => p.colUsd   > 0).sort((a, b) => b.colUsd   - a.colUsd)[0];
  if (!debtMkt || !colMkt) return;
  const debtToCover  = debtMkt.borrowUsd * CLOSE_FACTOR;
  const netProfitUsd = debtToCover * (LIQ_INCENTIVE - 1.0);
    // HARD GATE: greys (HF >= 1) never enter the fire queue — watch logs only.
  if (hf >= 1.0) {
    console.log(`[moonwell] near hf=${hf.toFixed(4)} col=$${totalColUsd.toFixed(0)} debt=$${totalBorrowUsd.toFixed(0)} ${colMkt.uSymbol}/${debtMkt.uSymbol} — NOT queued`);
    return;
  }
  if (netProfitUsd < 10) return;
  const priorityScore = 999999;
  console.log(`[moonwell] UNDERWATER hf=${hf.toFixed(4)} col=$${totalColUsd.toFixed(0)} debt=$${totalBorrowUsd.toFixed(0)} ${colMkt.uSymbol}/${debtMkt.uSymbol} ${user}`);
  upsertLiquidationQueue({

    user, collateral_asset: colMkt.mToken, collateral_symbol: colMkt.uSymbol,
    debt_asset: debtMkt.underlying, debt_symbol: debtMkt.uSymbol,
    collateral_value_usd: totalColUsd, debt_value_usd: totalBorrowUsd,
    debt_to_cover: String(debtToCover), net_profit_usd: netProfitUsd,
    gas_estimate: 700000, priority_score: priorityScore,
    protocol: "moonwell", market_id: debtMkt.mToken, comet_address: COMPTROLLER,
  });
}

export async function runMoonwellScanner(provider: ethers.providers.JsonRpcProvider): Promise<void> {
  console.log("[moonwell] Moonwell Compound V2 scanner starting on Base mainnet");
  const oracle  = new ethers.Contract(ORACLE_ADDR, ORACLE_ABI, provider);
  let markets: MktInfo[] = [];
  let state = loadState();
  while (true) {
    try {
      if (markets.length === 0) markets = await loadMarkets(provider);
      console.log(`[moonwell] discovery pass — ${state.borrowers.length} known borrowers`);
      await discoverBorrowers(provider, markets, state);
      saveState(state);
      const block  = await provider.getBlockNumber();
      console.log(`[moonwell] screening ${state.borrowers.length} borrowers — blk=${block}`);
      const atRisk = await screenBorrowers(provider, state.borrowers);
      console.log(`[moonwell] ${atRisk.length} at-risk — enriching`);
      for (let i = 0; i < atRisk.length; i += DETAIL_BATCH) {
        const slice = atRisk.slice(i, i + DETAIL_BATCH);
        await Promise.all(slice.map(user => enrichUser(provider, user, markets, oracle, block).catch(() => {})));
        await sleep(100);
      }
      logEvent("moonwell", "scan_complete", `borrowers=${state.borrowers.length} at_risk=${atRisk.length}`);
      console.log(`[moonwell] cycle complete — ${state.borrowers.length} borrowers, ${atRisk.length} at-risk`);
    } catch (e: any) {
      console.error("[moonwell] cycle error:", e.message);
    }
    await sleep(SCAN_INTERVAL);
  }
}
