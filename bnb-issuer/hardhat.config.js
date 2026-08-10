require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
const fs = require("fs");
const path = require("path");

// Reads the private key straight out of secrets.local.txt (written by
// generate_wallet.js), matching base-issuer's and stellar-issuer's
// pattern -- no separate .env file to manage.
function loadDeployerKey() {
  const secretsPath = path.join(__dirname, "secrets.local.txt");
  if (!fs.existsSync(secretsPath)) return undefined;
  const match = fs.readFileSync(secretsPath, "utf8").match(/Private key:\s*(0x[0-9a-fA-F]{64})/);
  return match ? match[1] : undefined;
}

const DEPLOYER_KEY = process.env.DEPLOYER_PRIVATE_KEY || loadDeployerKey();

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    hardhat: {
      forking: process.env.FORK_BSC
        ? { url: process.env.BSC_RPC_URL || "https://bsc-dataseed.binance.org/" }
        : undefined,
    },
    bsc: {
      url: process.env.BSC_RPC_URL || "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: DEPLOYER_KEY ? [DEPLOYER_KEY] : [],
    },
  },
};
