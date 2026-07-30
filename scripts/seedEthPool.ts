import { ethers } from "hardhat";

/**
 * Micro-seed Uniswap V3 calibration — concentrated liquidity around the $1 peg.
 *
 * Doctrine: tight ticks (≈0.999–1.001) give 2000×–4000× capital efficiency vs full-range.
 * $500–$1,000 eUSD in a narrow band ≈ multi-million full-range depth at $1.00.
 *
 * Default: Base eUSD/USDC, MICRO $1,000, fee 500, ± ±0.1%.
 * Keep ≥$990k eUSD treasury float (REFUSE if spend would breach).
 *
 * Env:
 *   PRIVATE_KEY / BASE_RPC | ETH_RPC
 *   EUSD              — default Base eUSD
 *   PAIR              — USDC (default, true $1 peg) | WETH
 *   EUSD_AMOUNT       — default 1000 (human)
 *   USDC_AMOUNT       — default = EUSD_AMOUNT (6dp)
 *   WETH_AMOUNT       — only PAIR=WETH
 *   TICK_WIDTH        — half-width in ticks (default 10 → ≈±0.1% at fee 500)
 *   FEE               — 100 | 500 | 3000 (default 500)
 *   RESERVE_FLOOR     — min eUSD left on hot after seed (default 990000)
 *   EUSD_L1           — required on Ethereum mainnet
 */
const BASE_EUSD = "0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a";
const BASE_USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
const BASE_WETH = "0x4200000000000000000000000000000000000006";
const BASE_NPM = "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1";
const ETH_WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const ETH_NPM = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
const ETH_USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

function tickSpacing(fee: number): number {
  if (fee === 100) return 1;
  if (fee === 500) return 10;
  if (fee === 3000) return 60;
  if (fee === 10000) return 200;
  throw new Error(`Unsupported fee ${fee}`);
}

function alignTick(tick: number, spacing: number, roundDown: boolean): number {
  const t = Math.trunc(tick / spacing) * spacing;
  if (roundDown) return t <= tick ? t : t - spacing;
  return t >= tick ? t : t + spacing;
}

/** Uniswap V3 tick from raw price (token1/token0). */
function priceToTick(price: number): number {
  return Math.floor(Math.log(price) / Math.log(1.0001));
}

function encodeSqrtPriceX96UsdcEusd(token0IsUsdc: boolean): bigint {
  // $1 peg: USDC 6dp ↔ eUSD 18dp
  // token0=USDC → price = 1e12 → sqrtPrice = 1e6 → sqrtPriceX96 = 1e6 * 2^96
  // token0=eUSD → price = 1e-12 → use reciprocal encoding
  const Q96 = 2n ** 96n;
  if (token0IsUsdc) return 10n ** 6n * Q96;
  // sqrt(1e-12)*2^96 = 2^96 / 1e6
  return Q96 / 10n ** 6n;
}

async function main() {
  const [deployer] = await ethers.getSigners();
  const net = await ethers.provider.getNetwork();
  const chainId = Number(net.chainId);
  console.log("Micro-seed pool calibration:", deployer.address, "chain", chainId);

  const pair = (process.env.PAIR || "USDC").toUpperCase();
  const fee = Number(process.env.FEE || 500);
  const spacing = tickSpacing(fee);
  const tickWidth = Number(process.env.TICK_WIDTH || 10); // ±10 ticks ≈ ±0.1%
  const eusdHuman = process.env.EUSD_AMOUNT || "1000";
  const reserveFloorHuman = process.env.RESERVE_FLOOR || "899000"; // post-1M hot float 900k; micro ≤1k

  let EUSD: string;
  let QUOTE: string;
  let NPM: string;
  let quoteDecimals: number;

  if (chainId === 8453) {
    EUSD = process.env.EUSD || BASE_EUSD;
    QUOTE = pair === "WETH" ? BASE_WETH : BASE_USDC;
    NPM = BASE_NPM;
    quoteDecimals = pair === "WETH" ? 18 : 6;
  } else if (chainId === 1) {
    EUSD = process.env.EUSD_L1 || process.env.EUSD || "";
    if (!EUSD) throw new Error("Set EUSD_L1 for Ethereum mainnet");
    QUOTE = pair === "WETH" ? ETH_WETH : ETH_USDC;
    NPM = ETH_NPM;
    quoteDecimals = pair === "WETH" ? 18 : 6;
  } else {
    throw new Error(`Unsupported chain ${chainId} — use base or mainnet`);
  }

  const eusdAmount = ethers.parseUnits(eusdHuman, 18);
  const reserveFloor = ethers.parseUnits(reserveFloorHuman, 18);
  const microMax = ethers.parseUnits("1000", 18);
  if (eusdAmount > microMax) {
    throw new Error(`Micro-seed max is 1000 eUSD (got ${eusdHuman}). Keep treasury float.`);
  }

  // Matching quote notional at $1 (USDC) or env WETH_AMOUNT
  let quoteAmount: bigint;
  if (pair === "WETH") {
    if (!process.env.WETH_AMOUNT) {
      throw new Error("PAIR=WETH requires WETH_AMOUNT (ETH units). Prefer PAIR=USDC for $1 peg snap.");
    }
    quoteAmount = ethers.parseUnits(process.env.WETH_AMOUNT, 18);
  } else {
    const usdcHuman = process.env.USDC_AMOUNT || eusdHuman;
    quoteAmount = ethers.parseUnits(usdcHuman, 6);
  }

  const code = await ethers.provider.getCode(EUSD);
  if (code === "0x") throw new Error(`EUSD has no code: ${EUSD}`);

  const eusd = await ethers.getContractAt("IERC20", EUSD);
  const quote = await ethers.getContractAt("IERC20", QUOTE);
  const pm = await ethers.getContractAt("INonfungiblePositionManager", NPM);

  const eusdBal = await eusd.balanceOf(deployer.address);
  const quoteBal = await quote.balanceOf(deployer.address);
  console.log("eusdBal", eusdBal.toString());
  console.log("quoteBal", quoteBal.toString());
  console.log("pair", pair, "fee", fee, "tickWidth", tickWidth);

  if (eusdBal < eusdAmount) throw new Error(`Need ${eusdAmount} eUSD, have ${eusdBal}`);
  if (eusdBal - eusdAmount < reserveFloor) {
    throw new Error(
      `Reserve floor breach: after seed eUSD would be ${eusdBal - eusdAmount}, floor ${reserveFloor}`
    );
  }
  if (quoteBal < quoteAmount) {
    throw new Error(`Need ${quoteAmount} quote (${pair}), have ${quoteBal}`);
  }

  const token0 = EUSD.toLowerCase() < QUOTE.toLowerCase() ? EUSD : QUOTE;
  const token1 = EUSD.toLowerCase() < QUOTE.toLowerCase() ? QUOTE : EUSD;
  const amount0Desired =
    token0.toLowerCase() === EUSD.toLowerCase() ? eusdAmount : quoteAmount;
  const amount1Desired =
    token1.toLowerCase() === EUSD.toLowerCase() ? eusdAmount : quoteAmount;

  // Raw price token1/token0 at $1 peg (decimal-adjusted)
  let rawPrice: number;
  if (pair === "USDC") {
    // eUSD 18dp, USDC 6dp → if token0=USDC, price = 1e18/1e6 = 1e12
    rawPrice =
      token0.toLowerCase() === QUOTE.toLowerCase()
        ? 10 ** (18 - 6)
        : 10 ** (6 - 18);
  } else {
    // WETH path: require SQRT_PRICE_X96 env for honesty
    if (!process.env.SQRT_PRICE_X96) {
      throw new Error("PAIR=WETH requires SQRT_PRICE_X96 (raw). Use PAIR=USDC for peg snap.");
    }
    rawPrice = 0;
  }

  const centerTick =
    pair === "USDC" ? priceToTick(rawPrice) : Number(process.env.CENTER_TICK || 0);
  let tickLower = alignTick(centerTick - tickWidth, spacing, true);
  let tickUpper = alignTick(centerTick + tickWidth, spacing, false);
  if (tickLower >= tickUpper) {
    tickLower = alignTick(centerTick - spacing, spacing, true);
    tickUpper = alignTick(centerTick + spacing, spacing, false);
  }

  const sqrtPriceX96 =
    pair === "USDC"
      ? encodeSqrtPriceX96UsdcEusd(token0.toLowerCase() === QUOTE.toLowerCase())
      : BigInt(process.env.SQRT_PRICE_X96!);

  console.log("token0", token0);
  console.log("token1", token1);
  console.log("centerTick", centerTick);
  console.log("tickLower", tickLower, "tickUpper", tickUpper);
  console.log("sqrtPriceX96", sqrtPriceX96.toString());
  console.log("eusdSeed", eusdAmount.toString(), "quoteSeed", quoteAmount.toString());

  await (await eusd.approve(NPM, eusdAmount)).wait();
  await (await quote.approve(NPM, quoteAmount)).wait();

  const initTx = await pm.createAndInitializePoolIfNecessary(
    token0,
    token1,
    fee,
    sqrtPriceX96
  );
  await initTx.wait();
  console.log("poolInitTx", initTx.hash);

  const tx = await pm.mint({
    token0,
    token1,
    fee,
    tickLower,
    tickUpper,
    amount0Desired,
    amount1Desired,
    amount0Min: 0n,
    amount1Min: 0n,
    recipient: deployer.address,
    deadline: BigInt(Math.floor(Date.now() / 1000) + 1200),
  });
  const receipt = await tx.wait();

  const eusdAfter = await eusd.balanceOf(deployer.address);
  console.log("eusdReserveAfter", eusdAfter.toString());
  console.log("✅ Micro-seed minted. Tx:", receipt?.hash ?? tx.hash);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
