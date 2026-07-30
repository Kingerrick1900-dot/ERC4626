import { ethers } from "hardhat";

/**
 * Base Maker PSM — dust capitalize (micro preflight).
 *
 * Live PSM: 0xfFEd7981f924Edc652E9b767aCa601505dfa4977
 * Doctrine: keep $990k+ eUSD float; only dust USDC into PSM for contract/preflight green.
 *
 * Env:
 *   PRIVATE_KEY / BASE_RPC
 *   PSM           — default live Maker PSM
 *   USDC_AMOUNT   — default 1 (human $1) dust; was 25000
 *   MODE          — seed (default dust) | mint
 *   SKIP_IF_RESERVED — if 1 and reserve>0, no-op success (already WIRE-seeded)
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Base PSM dust capitalize:", deployer.address);

  const net = await ethers.provider.getNetwork();
  if (Number(net.chainId) !== 8453) {
    throw new Error(`Expected Base (8453), got chainId ${net.chainId}`);
  }

  const PSM = process.env.PSM || "0xfFEd7981f924Edc652E9b767aCa601505dfa4977";
  const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  const mode = (process.env.MODE || "seed").toLowerCase();

  const amount = process.env.USDC_AMOUNT
    ? ethers.parseUnits(process.env.USDC_AMOUNT, 6)
    : ethers.parseUnits("1", 6); // $1 dust default

  const usdc = await ethers.getContractAt("IERC20", USDC);
  const psm = await ethers.getContractAt("IPSMModule", PSM);

  const reserveBefore = await psm.usdcReserve();
  console.log("psmReserveBefore", reserveBefore.toString());

  if (process.env.SKIP_IF_RESERVED === "1" && reserveBefore > 0n) {
    console.log("✅ Base PSM already has reserve — skip dust. Reserve:", reserveBefore.toString());
    return;
  }

  const bal = await usdc.balanceOf(deployer.address);
  console.log("hotUsdc", bal.toString());
  if (bal < amount) {
    throw new Error(
      `Need ${amount} USDC dust (6dp), have ${bal}. PSM may already be WIRE-seeded — set SKIP_IF_RESERVED=1.`
    );
  }

  await (await usdc.approve(PSM, amount)).wait();

  let tx;
  if (mode === "mint") {
    tx = await psm.mint(amount, deployer.address);
  } else {
    tx = await psm.seedUsdc(amount);
  }
  const receipt = await tx.wait();

  console.log("psmReserveAfter", (await psm.usdcReserve()).toString());
  console.log("✅ Base PSM dust capitalized. Tx:", receipt?.hash ?? tx.hash);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
