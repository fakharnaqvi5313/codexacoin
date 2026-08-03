// Creates the CAC/WETH Uniswap V2 pool on Base (auto-created by
// addLiquidityETH if it doesn't exist yet) and seeds it with the initial
// liquidity below. Real ETH and real CAC (the wrapped ERC-20, already
// minted to the deployer by deploy.js) both get locked into the pool by
// this transaction -- this is real capital, not a resting/cancelable offer
// like the Stellar sell offer was.
//
// Sizing: chosen to imply roughly the same CAC price as the existing
// Stellar peg (1 XLM = 14 CAC), using XLM ~$0.175 and ETH ~$1,850
// (2026-08-03 spot prices) => 1 CAC ~= $0.0125 => 1 ETH ~= 148,000 CAC.
const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

// Official Uniswap V2 Router02 on Base (verified against BaseScan directly,
// not just Uniswap's docs -- see PARAMETERS.md for the verification steps).
const ROUTER02_ADDRESS = "0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24";

const ETH_AMOUNT = hre.ethers.parseEther("0.05");
const CAC_AMOUNT = hre.ethers.parseUnits("7400", 18); // ~148,000 CAC per ETH

const ROUTER_ABI = [
  "function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity)",
];
const ERC20_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
];

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const { address: tokenAddress } = JSON.parse(
    fs.readFileSync(path.join(__dirname, "..", "deployed.json"), "utf8")
  );

  const token = new hre.ethers.Contract(tokenAddress, ERC20_ABI, deployer);
  const router = new hre.ethers.Contract(ROUTER02_ADDRESS, ROUTER_ABI, deployer);

  console.log(`Approving router to spend ${hre.ethers.formatUnits(CAC_AMOUNT, 18)} CAC...`);
  const approveTx = await token.approve(ROUTER02_ADDRESS, CAC_AMOUNT);
  await approveTx.wait();
  console.log(`Approved: ${approveTx.hash}`);

  const deadline = Math.floor(Date.now() / 1000) + 600; // 10 minutes
  // 2% slippage tolerance on both sides, since this is the pool's first
  // deposit and the ratio we set IS the price -- there's nothing to slip
  // against yet, but the router still requires min bounds.
  const minCac = (CAC_AMOUNT * 98n) / 100n;
  const minEth = (ETH_AMOUNT * 98n) / 100n;

  console.log(`Adding liquidity: ${hre.ethers.formatEther(ETH_AMOUNT)} ETH + ${hre.ethers.formatUnits(CAC_AMOUNT, 18)} CAC...`);
  const addLiqTx = await router.addLiquidityETH(
    tokenAddress,
    CAC_AMOUNT,
    minCac,
    minEth,
    deployer.address,
    deadline,
    { value: ETH_AMOUNT }
  );
  const receipt = await addLiqTx.wait();
  console.log(`Pool seeded: ${receipt.hash}`);
  console.log();
  console.log(`Verify at: https://basescan.org/tx/${receipt.hash}`);
  console.log(`Pool page (once indexed): https://www.geckoterminal.com/base/uniswap-v2-base/pools`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
