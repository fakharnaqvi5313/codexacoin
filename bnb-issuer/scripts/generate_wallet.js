// One-time EVM keypair generation for the deployer/distributor wallet used
// on BNB Smart Chain. Pure local key generation -- no network call, no
// funds moved -- so this is safe to run directly, same as
// base-issuer/scripts/generate_wallet.js and stellar-issuer's
// generate_keys.py. Secret written only to secrets.local.txt (gitignored).
const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

const wallet = ethers.Wallet.createRandom();

const secretsPath = path.join(__dirname, "..", "secrets.local.txt");
fs.writeFileSync(
  secretsPath,
  "CAC BNB Chain deployer/distributor account (mints the fixed supply, seeds the PancakeSwap pool)\n" +
    `Address: ${wallet.address}\n` +
    `Private key: ${wallet.privateKey}\n`
);
fs.chmodSync(secretsPath, 0o600);

console.log("Secret written to secrets.local.txt (chmod 600, gitignored).");
console.log();
console.log(`Deployer/distributor address: ${wallet.address}`);
console.log();
console.log("Doesn't exist as a funded account yet -- needs real BNB (for gas)");
console.log("and real USDT (for pool liquidity) sent to it before deploy.js or");
console.log("create_pool_and_seed.js can run.");
