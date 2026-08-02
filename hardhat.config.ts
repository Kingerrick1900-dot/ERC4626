import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";

const PRIVATE_KEY = process.env.PRIVATE_KEY || process.env.ETH_PRIVATE_KEY || "";
const accounts = PRIVATE_KEY ? [PRIVATE_KEY] : [];

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  paths: {
    sources: "./contracts/seed",
    tests: "./tests",
    cache: "./cache-hardhat",
    artifacts: "./artifacts-hardhat",
  },
  networks: {
    hardhat: {},
    mainnet: {
      url: process.env.ETH_RPC || process.env.MAINNET_RPC || "https://ethereum.publicnode.com",
      chainId: 1,
      accounts,
    },
    base: {
      url: process.env.BASE_RPC || process.env.BASE_RPC_URL || process.env.RPC_URL || "https://mainnet.base.org",
      chainId: 8453,
      accounts,
    },
  },
};

export default config;
