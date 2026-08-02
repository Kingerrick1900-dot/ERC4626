import { ethers } from "hardhat";

/**
 * Script 1 — Seed L1 eUSD/WETH Uniswap V3 pool (Ethereum mainnet).
 *
 * Env:
 *   PRIVATE_KEY     — deployer (King hot)
 *   ETH_RPC         — Ethereum RPC
 *   EUSD_L1         — L1 eUSD address (required; Base eUSD is NOT on L1)
 *   EUSD_AMOUNT     — default 50000 eUSD (18dp)
 *   WETH_AMOUNT     — default 15 WETH (18dp)
 *   SQRT_PRICE_X96  — pool init price if pool missing (default ≈ 1 eUSD = 1/2500 WETH)
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Seeding L1 eUSD/WETH pool:", deployer.address);

  const EUSD = process.env.EUSD_L1;
  if (!EUSD) {
    throw new Error("Set EUSD_L1 — Kingdom eUSD on Base is not deployed on Ethereum L1");
  }
  const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const POSITION_MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";

  const eusdAmount = process.env.EUSD_AMOUNT
    ? ethers.parseUnits(process.env.EUSD_AMOUNT, 18)
    : ethers.parseUnits("50000", 18);
  const wethAmount = process.env.WETH_AMOUNT
    ? ethers.parseUnits(process.env.WETH_AMOUNT, 18)
    : ethers.parseUnits("15", 18);

  // Default: token1/token0 ≈ WETH per eUSD when eUSD < WETH → ~1/2500
  // sqrt(1/2500) * 2^96 ≈ 1.58113883e33... use fixed hex.
  const SQRT_PRICE_X96 = BigInt(
    process.env.SQRT_PRICE_X96 || "1581388301933583020288122980705"
  );

  const code = await ethers.provider.getCode(EUSD);
  if (code === "0x") throw new Error(`EUSD_L1 has no code: ${EUSD}`);

  const eusd = await ethers.getContractAt("IERC20", EUSD);
  const weth = await ethers.getContractAt("IERC20", WETH);
  const pm = await ethers.getContractAt("INonfungiblePositionManager", POSITION_MANAGER);

  const eusdBal = await eusd.balanceOf(deployer.address);
  const wethBal = await weth.balanceOf(deployer.address);
  console.log("eusdBal", eusdBal.toString());
  console.log("wethBal", wethBal.toString());
  if (eusdBal < eusdAmount) throw new Error(`Need ${eusdAmount} eUSD, have ${eusdBal}`);
  if (wethBal < wethAmount) throw new Error(`Need ${wethAmount} WETH, have ${wethBal}`);

  const token0 = EUSD.toLowerCase() < WETH.toLowerCase() ? EUSD : WETH;
  const token1 = EUSD.toLowerCase() < WETH.toLowerCase() ? WETH : EUSD;
  const amount0Desired = token0.toLowerCase() === EUSD.toLowerCase() ? eusdAmount : wethAmount;
  const amount1Desired = token1.toLowerCase() === EUSD.toLowerCase() ? eusdAmount : wethAmount;

  await (await eusd.approve(POSITION_MANAGER, eusdAmount)).wait();
  await (await weth.approve(POSITION_MANAGER, wethAmount)).wait();

  const pool = await (
    await pm.createAndInitializePoolIfNecessary(token0, token1, 500, SQRT_PRICE_X96)
  ).wait();
  console.log("poolInitTx", pool?.hash);

  const params = {
    token0,
    token1,
    fee: 500,
    tickLower: -887220,
    tickUpper: 887220,
    amount0Desired,
    amount1Desired,
    amount0Min: 0n,
    amount1Min: 0n,
    recipient: deployer.address,
    deadline: BigInt(Math.floor(Date.now() / 1000) + 1200),
  };

  const tx = await pm.mint(params);
  const receipt = await tx.wait();
  console.log("✅ L1 pool seeded. Tx:", receipt?.hash ?? tx.hash);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
