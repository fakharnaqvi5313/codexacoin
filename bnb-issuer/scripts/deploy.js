// Deploys CodexaCoinBnb.sol to BNB Smart Chain mainnet: mints the full
// fixed supply (RESERVE_BACKED_SUPPLY) to the deployer/distributor
// wallet in the same transaction. There is no owner and no mint
// function -- this is the only issuance event that will ever happen
// for this contract.
//
// RESERVE_BACKED_SUPPLY must exactly match the real CAC locked in the
// `bnb-reserve` wallet on the CAC chain. Set to 2,000,000 CAC, matching
// the Base reserve exactly (same "deliberately conservative for a
// still-unproven venue" reasoning -- see base-issuer/README.md).
const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

const RESERVE_BACKED_SUPPLY = hre.ethers.parseUnits("2000000", 18);

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying from: ${deployer.address}`);

  const Factory = await hre.ethers.getContractFactory("CodexaCoinBnb");
  const token = await Factory.deploy(RESERVE_BACKED_SUPPLY, deployer.address);
  await token.waitForDeployment();

  const address = await token.getAddress();
  console.log(`CodexaCoinBnb deployed to: ${address}`);
  console.log(`Minted ${hre.ethers.formatUnits(RESERVE_BACKED_SUPPLY, 18)} CAC to ${deployer.address}`);
  console.log();
  console.log(`Verify at: https://bscscan.com/token/${address}`);

  const deployedPath = path.join(__dirname, "..", "deployed.json");
  fs.writeFileSync(deployedPath, JSON.stringify({ address, deployer: deployer.address }, null, 2));
  console.log(`\nWrote contract address to deployed.json (needed by create_pool_and_seed.js).`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
