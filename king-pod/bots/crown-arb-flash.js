/**
 * crown-arb-flash — Uni V3 fee-tier arb via CrownFlashRouter (Morpho 0% → 5 bps King).
 * LIVE by default when LIVE=true. Replaces Balancer-capped flash path.
 */
"use strict";
const { ethers } = require("/opt/kesov-kingdom/node_modules/ethers");
require("/opt/kesov-kingdom/node_modules/dotenv").config({ path: "/opt/kesov-kingdom/.env" });

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const BASE_RPC = (process.env.RPC_URL || (process.env.RPC_URLS || "")
  .split(",")
  .map((s) => s.trim())
  .find((u) => u && !/drpc/i.test(u)) || "").trim();
if (!BASE_RPC) throw new Error("No RPC");
if (!PRIVATE_KEY) throw new Error("No PRIVATE_KEY");

const CONTRACT_ADDRESS = process.env.CROWN_FLASH_ARB || "0xD17D5aF60fDF495C50E5aced46CdC1C0E68F366d";
const CROWN_ROUTER = process.env.CROWN_FLASH_ROUTER || "0x13734BffdDFf6CbDE474B3F5467d86e813232577";
const UNISWAP_ROUTER = "0x2626664c2603336E57B271c5C0b26F421741e481";
const UNISWAP_QUOTER = "0x3D4e44EB8734244902f5e0E25f8FcD474382685b";
const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
const WETH = "0x4200000000000000000000000000000000000006";
const POOL_USDC_WETH_500 = "0xd0b53D9277642d899DF5C87A3966A349A798F224";
const POOL_USDC_WETH_3000 = "0x6c561B446416E1A00E8E93E221854d6eA4171372";
const FEE_LOW = 500;
const FEE_HIGH = 3000;

const QUOTER_ABI = [
  "function quoteExactInputSingle((address,address,uint24,uint256,uint160)) external returns (uint256,uint160,uint32,uint256)",
];
const POOL_ABI = ["function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool)"];
const CONTRACT_ABI = [
  "function flashArbitrage(uint256,address,bytes,address,bytes,uint256) external",
];
const ROUTER_ABI = ["function quoteFee(uint256) view returns (uint256)", "function feeBps() view returns (uint256)"];

const FLASH_AMOUNT = ethers.utils.parseUnits(process.env.ARB_FLASH_AMOUNT_USDC || "250000", 6);
const MIN_PROFIT_USD = Number(process.env.MIN_PROFIT_USD || 25);
const LIVE = String(process.env.LIVE || "false").toLowerCase() === "true";
const INTERVAL_MS = Number(process.env.CROWN_ARB_MS || 8000);

let provider, wallet, contract, quoter, poolLow, poolHigh, crownRouter, feeBps = 5;

async function getPriceFromPool(pool) {
  const slot = await pool.slot0();
  const sqrtPriceX96 = slot[0];
  const Q96 = ethers.BigNumber.from(2).pow(96);
  const sqrtPrice = sqrtPriceX96.mul(ethers.BigNumber.from(10).pow(18)).div(Q96);
  return sqrtPrice.mul(sqrtPrice).div(ethers.BigNumber.from(10).pow(18));
}

function computeOutputBig(amountIn, price, feeBpsSwap) {
  const feeFactor = ethers.BigNumber.from(10000 - feeBpsSwap);
  return amountIn
    .mul(price)
    .mul(feeFactor)
    .div(ethers.BigNumber.from(10000).mul(ethers.BigNumber.from(10).pow(18)));
}

async function getQuote(tokenIn, tokenOut, amountIn, fee) {
  try {
    const result = await Promise.race([
      quoter.callStatic.quoteExactInputSingle([tokenIn, tokenOut, fee, amountIn, 0]),
      new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), 5000)),
    ]);
    return Array.isArray(result) ? result[0] : result;
  } catch (err) {
    console.log(`Quoter error (fee ${fee}): ${String(err.message).slice(0, 60)} — pool fallback`);
    const pool = fee === 500 ? poolLow : poolHigh;
    const price = await getPriceFromPool(pool);
    if (tokenIn === USDC && tokenOut === WETH) return computeOutputBig(amountIn, price, fee === 500 ? 5 : 30);
    if (tokenIn === WETH && tokenOut === USDC) {
      const one = ethers.BigNumber.from(10).pow(18);
      const invPrice = one.mul(one).div(price);
      return amountIn
        .mul(invPrice)
        .mul(10000 - (fee === 500 ? 5 : 30))
        .div(ethers.BigNumber.from(10000).mul(one));
    }
    return ethers.BigNumber.from(0);
  }
}

function buildSwapData(tokenIn, tokenOut, amountIn, fee) {
  const iface = new ethers.utils.Interface([
    "function exactInputSingle((address tokenIn,address tokenOut,uint24 fee,address recipient,uint256 deadline,uint256 amountIn,uint256 amountOutMinimum,uint160 sqrtPriceLimitX96)) returns (uint256)",
  ]);
  return iface.encodeFunctionData("exactInputSingle", [
    {
      tokenIn,
      tokenOut,
      fee,
      recipient: CONTRACT_ADDRESS,
      deadline: Math.floor(Date.now() / 1000) + 300,
      amountIn,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0,
    },
  ]);
}

async function getGasFees() {
  const feeData = await provider.getFeeData();
  if (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas) {
    return { maxPriorityFeePerGas: feeData.maxPriorityFeePerGas, maxFeePerGas: feeData.maxFeePerGas };
  }
  const gasPrice = await provider.getGasPrice();
  return { maxPriorityFeePerGas: ethers.BigNumber.from(0), maxFeePerGas: gasPrice };
}

async function checkArbitrage() {
  try {
    const quoteLow = await getQuote(USDC, WETH, FLASH_AMOUNT, FEE_LOW);
    const quoteHigh = await getQuote(USDC, WETH, FLASH_AMOUNT, FEE_HIGH);
    if (quoteLow.isZero() || quoteHigh.isZero()) {
      console.log("Quotes zero, skipping");
      return;
    }

    const buyOnLow = quoteLow.gt(quoteHigh);
    const buyFee = buyOnLow ? FEE_LOW : FEE_HIGH;
    const sellFee = buyOnLow ? FEE_HIGH : FEE_LOW;
    const wethReceived = buyOnLow ? quoteLow : quoteHigh;

    const sellQuote = await getQuote(WETH, USDC, wethReceived, sellFee);
    let flashFee;
    try {
      flashFee = await Promise.race([
        crownRouter.quoteFee(FLASH_AMOUNT),
        new Promise((_, rej) => setTimeout(() => rej(new Error("fee timeout")), 4000)),
      ]);
    } catch (_) {
      flashFee = FLASH_AMOUNT.mul(feeBps).div(10000); // local Crown fee math
    }
    const repay = FLASH_AMOUNT.add(flashFee);
    const profitBig = sellQuote.sub(repay);
    const profitUSD = parseFloat(ethers.utils.formatUnits(profitBig, 6));

    console.log(
      `[${new Date().toISOString()}] CROWN buyFee=${buyFee} sellFee=${sellFee} feeBps=${feeBps} profit=$${profitUSD.toFixed(2)} LIVE=${LIVE}`
    );

    if (profitUSD > MIN_PROFIT_USD) {
      if (!LIVE) {
        console.log(`DRY — edge $${profitUSD.toFixed(2)} (set LIVE=true to fire)`);
        return;
      }
      console.log(`🚀 CROWN FLASH Executing: $${profitUSD.toFixed(2)}`);
      const swapDataBuy = buildSwapData(USDC, WETH, FLASH_AMOUNT, buyFee);
      const swapDataSell = buildSwapData(WETH, USDC, wethReceived, sellFee);
      const gas = await getGasFees();
      const minProfit = ethers.utils.parseUnits(String(Math.floor(MIN_PROFIT_USD)), 6);
      const tx = await contract.flashArbitrage(
        FLASH_AMOUNT,
        UNISWAP_ROUTER,
        swapDataBuy,
        UNISWAP_ROUTER,
        swapDataSell,
        minProfit,
        { maxPriorityFeePerGas: gas.maxPriorityFeePerGas, maxFeePerGas: gas.maxFeePerGas, gasLimit: 900000 }
      );
      console.log(`  Tx: ${tx.hash}`);
      await tx.wait(1);
      console.log("✅ Crown flash success");
    }
  } catch (err) {
    console.error("Error:", err.message);
  }
}

async function init() {
  provider = new ethers.providers.StaticJsonRpcProvider(BASE_RPC, { chainId: 8453, name: "base" });
  wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);
  crownRouter = new ethers.Contract(CROWN_ROUTER, ROUTER_ABI, provider);
  quoter = new ethers.Contract(UNISWAP_QUOTER, QUOTER_ABI, provider);
  poolLow = new ethers.Contract(POOL_USDC_WETH_500, POOL_ABI, provider);
  poolHigh = new ethers.Contract(POOL_USDC_WETH_3000, POOL_ABI, provider);
  try {
    feeBps = Number((await crownRouter.feeBps()).toString());
  } catch (_) {}
  console.log(
    `crown-arb-flash started | ${ethers.utils.formatUnits(FLASH_AMOUNT, 6)} USDC | Crown ${feeBps}bps→King | Morpho 0% | minProfit=$${MIN_PROFIT_USD} | LIVE=${LIVE} | arb=${CONTRACT_ADDRESS}`
  );
  checkArbitrage();
  setInterval(checkArbitrage, INTERVAL_MS);
}

init().catch(console.error);
