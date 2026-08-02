import { ethers } from "hardhat";

/**
 * Script 2 — Capitalize Base USDC PSM (Maker mint leg).
 *
 * Live PSM: 0xfFEd7981f924Edc652E9b767aCa601505dfa4977
 * mint(usdc, to) pulls USDC into reserve and mints eUSD 1:1.
 *
 * Env:
 *   PRIVATE_KEY   — Base hot (PSM owner / USDC holder)
 *   BASE_RPC      — Base RPC
 *   PSM           — override PSM address
 *   USDC_AMOUNT   — default 25000 (6dp human units)
 *   MODE          — "mint" (default, King script) | "seed" (seedUsdc only, no eUSD mint)
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Capitalizing Base PSM:", deployer.address);

  const net = await ethers.provider.getNetwork();
  if (Number(net.chainId) !== 8453) {
    throw new Error(`Expected Base (8453), got chainId ${net.chainId}`);
  }

  const PSM = process.env.PSM || "0xfFEd7981f924Edc652E9b767aCa601505dfa4977";
  const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  const mode = (process.env.MODE || "mint").toLowerCase();

  const amount = process.env.USDC_AMOUNT
    ? ethers.parseUnits(process.env.USDC_AMOUNT, 6)
    : ethers.parseUnits("25000", 6);

  const usdc = await ethers.getContractAt("IERC20", USDC);
  const psm = await ethers.getContractAt("IPSMModule", PSM);

  const bal = await usdc.balanceOf(deployer.address);
  console.log("hotUsdc", bal.toString());
  console.log("psmReserveBefore", (await psm.usdcReserve()).toString());
  if (bal < amount) {
    throw new Error(
      `Need ${amount} USDC (6dp) to capitalize, have ${bal}. Fund hot, then re-run.`
    );
  }

  await (await usdc.approve(PSM, amount)).wait();

  let tx;
  if (mode === "seed") {
    tx = await psm.seedUsdc(amount);
  } else {
    tx = await psm.mint(amount, deployer.address);
  }
  const receipt = await tx.wait();

  console.log("psmReserveAfter", (await psm.usdcReserve()).toString());
  console.log("✅ Base PSM capitalized. Tx:", receipt?.hash ?? tx.hash);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
