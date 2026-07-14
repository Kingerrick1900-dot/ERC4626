import { ethers } from "ethers";
import { ADDRESSES } from "./addresses";
import { KINGDOM_LIQUIDATOR_ABI, POOL_ADDRESSES_PROVIDER_ABI, PRICE_ORACLE_SENTINEL_ABI, ORACLE_ABI, ERC20_MINIMAL_ABI } from "./abis";
import { claimNextTarget, markQueueFailed, markQueueDone, insertExecution, logEvent, releaseTarget, releaseWithCooldown } from "./db";
import { decodeRevert, formatRevert } from "./revert-decode";

const LIVE = process.env.LIVE === "true" || process.env.LIVE === "1";
const SWAP_FEE = parseInt(process.env.SWAP_FEE_TIER || "500", 10);
const MIN_PROFIT_USD = -Infinity; // King: execute ALL

let executionCount = 0;

export async function runExecutor(provider: ethers.providers.JsonRpcProvider): Promise<void> {
  const POLL_MS = parseInt(process.env.POLL_INTERVAL_MS || "5000", 10);
  console.log(`[executor] started — LIVE=${LIVE} poll=${POLL_MS}ms`);

  while (true) {
    try {
      await executionCycle(provider);
    } catch (e: any) {
      console.error("[executor] cycle error:", formatRevert(decodeRevert(e, provider)));
    }
    await new Promise(r => setTimeout(r, POLL_MS));
  }
}

async function executionCycle(provider: ethers.providers.JsonRpcProvider): Promise<void> {
  const cycleId = `cycle_${Date.now()}`;
  const target = claimNextTarget(cycleId, "aave");
  if (!target) return;

  // Protocol guard — release non-Aave rows back so the correct executor can claim them
  if (target.protocol && target.protocol !== 'aave') {
    console.error(`[executor] PROTOCOL MISMATCH — ${target.user} has protocol=${target.protocol}, expected aave — releasing`);
    releaseTarget(target.id);
    return;
  }

  console.log(`[executor] claimed target ${target.user} — debt=${target.debt_symbol} col=${target.collateral_symbol} profit=$${target.net_profit_usd.toFixed(2)}`);

  // ── Threshold filter (env-driven: MIN_DEBT_THRESHOLD / MIN_COLLATERAL_THRESHOLD) ──
  const MIN_DEBT  = parseFloat(process.env.MIN_DEBT_THRESHOLD || "5000");
  const MIN_COLL  = parseFloat(process.env.MIN_COLLATERAL_THRESHOLD || "1000");
  const debtInUSD = parseFloat(target.debt_to_cover);
  const collUSD   = target.collateral_value_usd || 0;
  if (debtInUSD < MIN_DEBT || collUSD < MIN_COLL) {
    const fmtUsd = (n: number) => n >= 1 ? `$${n.toFixed(2)}` : `$${n.toPrecision(3)}`;
    markQueueFailed(target.id, `dust: debt=${fmtUsd(debtInUSD)} coll=${fmtUsd(collUSD)} need>debt$${MIN_DEBT}/coll$${MIN_COLL}`);
    console.log(`[executor] dust-skip ${target.user} — debt=${fmtUsd(debtInUSD)} coll=${fmtUsd(collUSD)} (need debt>$${MIN_DEBT} coll>$${MIN_COLL})`);
    return;
  }
  // No profit floor — King executes all

  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey || !/^0x[0-9a-fA-F]{64}$/.test(privateKey)) {
    markQueueFailed(target.id, "PRIVATE_KEY not set or invalid");
    return;
  }

  const wallet = new ethers.Wallet(privateKey, provider);
  const liquidator = new ethers.Contract(ADDRESSES.KINGDOM_LIQUIDATOR, KINGDOM_LIQUIDATOR_ABI, wallet);

  // ── On-chain HF guard (skip healthy positions immediately) ─────────────────
  try {
    const pool = new ethers.Contract(ADDRESSES.POOL,
      ["function getUserAccountData(address) view returns (uint256,uint256,uint256,uint256,uint256,uint256)"],
      provider);
    const acct = await pool.getUserAccountData(target.user);
    const hf   = acct[5]; // healthFactor is 6th return value
    const WAD  = ethers.BigNumber.from("1000000000000000000");
    if (hf.gte(WAD)) {
      const hfFloat = parseFloat(ethers.utils.formatUnits(hf, 18));
      const hfStr   = hfFloat.toFixed(4);
      if (hfFloat < 1.05) {
        const { strikes, backoffSec } = releaseWithCooldown(target.id, target.user);
        console.log(`[executor] 🟡 Near HF=${hfStr} — releasing for retry, strike=${strikes} cooldown=${backoffSec}s`);
      } else {
        markQueueFailed(target.id, 'healthy on-chain HF=' + hfStr);
        console.log('[executor] 🔒 Healthy HF=' + hfStr + ' — skip');
      }
      return;
    }
  } catch (e: any) {
    // HARD GATE: RPC/HF read failure must NEVER fall through to preflight.
    // Falling through was the primary source of HealthFactorNotBelowThreshold simfail spam.
    const { strikes, backoffSec } = releaseWithCooldown(target.id, target.user);
    console.warn(`[executor] HF check failed — NOT firing: ${e.message} cooldown=${backoffSec}s strikes=${strikes}`);
    return;
  }

    // ── Precise debtToCover: oracle price + per-token decimals ──────────────
  // debt_to_cover is stored as USD. Convert to token wei using:
  //   token_amount = usd_amount * 10^decimals / (oracle_price / 1e8)
  const debtToken  = new ethers.Contract(target.debt_asset, ERC20_MINIMAL_ABI, provider);
  const oracleCtx  = new ethers.Contract(ADDRESSES.ORACLE, ORACLE_ABI, provider);
  const [debtDecimals, debtPrice] = await Promise.all([
    debtToken.decimals(),
    oracleCtx.getAssetPrice(target.debt_asset), // USD price, 8 decimals
  ]);
  const debtToCoverUSDe8 = Math.round(parseFloat(target.debt_to_cover) * 1e8);
  const debtToCover = ethers.BigNumber.from(debtToCoverUSDe8.toString())
    .mul(ethers.BigNumber.from(10).pow(debtDecimals))
    .div(debtPrice);
  console.log(`[executor] debtToCover=${ethers.utils.formatUnits(debtToCover, debtDecimals)} ${target.debt_symbol} (${debtDecimals} dec, price=$${(debtPrice.toNumber()/1e8).toFixed(4)})`);

  // ── callStatic pre-flight simulation ─────────────────────────────────────
  // callStatic.flashLiquidate — simulates the tx without spending gas.
  // If the real tx would revert, this catches it here first.
  try {
    await liquidator.callStatic.liquidate(
      target.collateral_asset,
      target.debt_asset,
      target.user,
      debtToCover,
      SWAP_FEE,
      0
    );
    console.log(`[executor] callStatic preflight OK — proceeding`);
  } catch (e: any) {
    const decoded = decodeRevert(e, provider);
    const reason = `preflight reverted: ${formatRevert(decoded)}`;
    markQueueFailed(target.id, reason);
    // Do not inflate simfail counter with healthy greys (0x930bb771 = HealthFactorNotBelowThreshold)
    const healthySkip = /930bb771|HealthFactorNotBelowThreshold|healthy/i.test(reason);
    insertExecution({
      bot: 'kesov-aave',
      user: target.user,
      collateral_asset: target.collateral_asset,
      debt_asset: target.debt_asset,
      status: healthySkip ? "healthy_skip" : "simfail",
      failure_reason: reason,
    });
    console.log(`[executor] preflight failed — skipping: ${reason}`);
    logEvent("executor", "preflight_failed", reason);
    return;
  }

  if (!LIVE) {
    markQueueDone(target.id);
    insertExecution({ bot: 'kesov-aave', user: target.user, collateral_asset: target.collateral_asset, debt_asset: target.debt_asset, status: "dryrun", net_profit_usd: target.net_profit_usd });
    console.log(`[executor] DRY-RUN — would liquidate ${target.user}. Set LIVE=true to execute.`);
    return;
  }

  // ── PriceOracleSentinel check (L2 sequencer grace period guard) ─────────
  try {
    const addressesProvider = new ethers.Contract(ADDRESSES.POOL_ADDRESSES_PROVIDER, POOL_ADDRESSES_PROVIDER_ABI, provider);
    const sentinelAddress: string = await addressesProvider.getPriceOracleSentinel();
    const sentinel = new ethers.Contract(sentinelAddress, PRICE_ORACLE_SENTINEL_ABI, provider);
    const liquidationAllowed: boolean = await sentinel.isLiquidationAllowed();
    if (!liquidationAllowed) {
      markQueueFailed(target.id, "sentinel: L2 grace period active");
      console.warn(`[SENTINEL] Liquidation blocked by L2 Grace Period — skipping ${target.user}`);
      logEvent("executor", "sentinel_blocked", `user=${target.user.slice(0,12)}`);
      return;
    }
    console.log(`[executor] sentinel OK — liquidation allowed`);
  } catch (e: any) {
    console.warn(`[executor] sentinel check failed (proceeding): ${e.message}`);
  }

  // ── Live Execution ────────────────────────────────────────────────────────
  let tx: ethers.ContractTransaction | null = null;
  let receipt: ethers.ContractReceipt | null = null;
  try {
    // ── EIP-1559 gas bidding (Base) ────────────────────────────────────
    // ── EIP-1559 gas bidding (Base) ────────────────────────────────────────
    const feeData        = await provider.getFeeData();
    const maxGasGwei     = parseFloat(process.env.MAX_GAS_PRICE_GWEI        || "50");
    const priorityMult   = parseFloat(process.env.GAS_PRIORITY_MULTIPLIER   || "3");

    const baseFee        = feeData.lastBaseFeePerGas
                        ?? feeData.gasPrice
                        ?? ethers.utils.parseUnits("0.1", "gwei");
    const medianPriority = feeData.maxPriorityFeePerGas
                        ?? ethers.utils.parseUnits("0.001", "gwei");

    // Bid priorityMult × network median priority fee (default 3×)
    const maxPriorityFeePerGas = medianPriority.mul(Math.round(priorityMult * 100)).div(100);
    // maxFeePerGas = 2 × baseFee + priorityFee  (absorbs baseFee spikes)
    const maxFeePerGas = baseFee.mul(2).add(maxPriorityFeePerGas);

    const maxFeeGwei = parseFloat(ethers.utils.formatUnits(maxFeePerGas, "gwei"));
    if (maxFeeGwei > maxGasGwei) {
      const reason = `maxFeePerGas ${maxFeeGwei.toFixed(3)} gwei exceeds cap ${maxGasGwei} gwei`;
      markQueueFailed(target.id, reason);
      console.log(`[executor] aborted: ${reason}`);
      return;
    }
    console.log(`[executor] EIP-1559 gas — base:${ethers.utils.formatUnits(baseFee,"gwei")}gwei priority:${ethers.utils.formatUnits(maxPriorityFeePerGas,"gwei")}gwei (${priorityMult}x) maxFee:${maxFeeGwei.toFixed(3)}gwei`);

    tx = await liquidator.liquidate(
      target.collateral_asset,
      target.debt_asset,
      target.user,
      debtToCover,
      SWAP_FEE,
      0,
      { gasLimit: 500_000, maxFeePerGas, maxPriorityFeePerGas, type: 2 }
    );

    if (!tx) { markQueueFailed(target.id, "tx object null after send"); return; }
    console.log(`[executor] tx submitted: ${tx.hash}`);
    receipt = await tx!.wait(1);

    const netProfitUsd = target.net_profit_usd;

    markQueueDone(target.id);
    insertExecution({ bot: 'kesov-aave',
      user: target.user,
      collateral_asset: target.collateral_asset,
      debt_asset: target.debt_asset,
      tx_hash: receipt.transactionHash,
      net_profit_usd: netProfitUsd,
      gas_used: receipt.gasUsed.toNumber(),
      status: "success",
      block_number: receipt.blockNumber,
      gas_cost_eth: receipt.effectiveGasPrice ? Number(ethers.utils.formatEther(receipt.gasUsed.mul(receipt.effectiveGasPrice))) : undefined,
    });

    executionCount++;

    // Sweep profit into KingVault
    try {
      const vaultContract = new ethers.Contract(ADDRESSES.KING_VAULT, ["function sweep(address token) external"], wallet);
      await vaultContract.sweep(target.debt_asset, { gasLimit: 150_000, maxFeePerGas, maxPriorityFeePerGas, type: 2 });
      console.log(`[executor] vault swept ${target.debt_symbol}`);
    } catch (ve: any) { console.log(`[executor] vault sweep skip: ${ve.message}`); }

    logEvent("executor", "liquidation_success", `tx=${receipt.transactionHash} profit=$${netProfitUsd.toFixed(2)}`);
    console.log(`[executor] ✅ LIQUIDATION CONFIRMED — tx:${receipt.transactionHash} profit:$${netProfitUsd.toFixed(2)} block:${receipt.blockNumber}`);

  } catch (e: any) {
    const decoded = decodeRevert(e, provider);
    const reason = formatRevert(decoded);
    markQueueFailed(target.id, reason);
    insertExecution({ bot: 'kesov-aave', user: target.user, collateral_asset: target.collateral_asset, debt_asset: target.debt_asset, tx_hash: tx?.hash, status: "failed", failure_reason: reason });
    logEvent("executor", "liquidation_failed", reason);
    console.error(`[executor] execution failed: ${reason}`);
  }
}
