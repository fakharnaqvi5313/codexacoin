// Creates the CAC/USDT PancakeSwap V2 pool on BNB Smart Chain (auto-
// created by addLiquidity if it doesn't exist yet) and seeds it with
// the initial liquidity below. Real USDT and real CAC (the wrapped
// BEP-20, already minted to the deployer by deploy.js) both get locked
// into the pool by this transaction -- this is real capital, not a
// resting/cancelable offer like the Stellar sell offer was.
//
// Deliberately quoted against USDT rather than BNB/WBNB: an AMM pool
// only holds the *ratio* between its two assets fixed (absent trades),
// so pooling against a volatile native asset like BNB or ETH means
// CAC's USD price drifts with that asset's own USD price -- unrelated
// to anything CAC-specific. Quoting against USDT (itself ~$1 by
// design) makes the pool's ratio *be* CAC's USD price directly, so
// BNB's own volatility has no effect on it. This does not make CAC a
// stablecoin -- its USDT price still moves with actual CAC supply/
// demand, same as any token -- it only removes the unrelated BNB
// volatility.
//
// Sizing: 21.41008673 USDT (this round's actual contribution, confirmed
// on-chain via the deployer address's USDT balance) at the $0.0125/CAC
// target price shared with the Stellar and Base venues => 1712.8069384
// CAC. Both numbers are trivially rescalable for a later top-up (same
// call, larger amounts) since PancakeSwap's addLiquidity works
// identically against an existing pair.
//
// Router/Factory/USDT addresses below were verified two independent
// ways before this script was written: BscScan contract-page lookup,
// and a direct eth_call to the Router's own factory()/WETH() view
// functions on-chain (which is how the Factory/WBNB addresses were
// actually obtained -- not typed in from memory).
const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

// PancakeSwap V2 Router on BSC mainnet (BscScan: "PancakeSwap: Router v2", verified source).
const ROUTER02_ADDRESS = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
// Binance-Peg BSC-USD (USDT), 18 decimals on BSC (NOT 6, unlike Ethereum's USDT --
// confirmed via decimals() eth_call before this constant was written).
const USDT_ADDRESS = "0x55d398326f99059fF775485246999027B3197955";

const USDT_AMOUNT = hre.ethers.parseUnits("21.41008673", 18);
const CAC_AMOUNT = hre.ethers.parseUnits("1712.8069384", 18); // 21.41008673 / 0.0125

const ROUTER_ABI = [
  "function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity)",
];
const ERC20_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
];

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const { address: tokenAddress } = JSON.parse(
    fs.readFileSync(path.join(__dirname, "..", "deployed.json"), "utf8")
  );

  const cac = new hre.ethers.Contract(tokenAddress, ERC20_ABI, deployer);
  const usdt = new hre.ethers.Contract(USDT_ADDRESS, ERC20_ABI, deployer);
  const router = new hre.ethers.Contract(ROUTER02_ADDRESS, ROUTER_ABI, deployer);

  console.log(`Approving router to spend ${hre.ethers.formatUnits(CAC_AMOUNT, 18)} CAC...`);
  const approveCacTx = await cac.approve(ROUTER02_ADDRESS, CAC_AMOUNT);
  await approveCacTx.wait();
  console.log(`Approved CAC: ${approveCacTx.hash}`);

  console.log(`Approving router to spend ${hre.ethers.formatUnits(USDT_AMOUNT, 18)} USDT...`);
  const approveUsdtTx = await usdt.approve(ROUTER02_ADDRESS, USDT_AMOUNT);
  await approveUsdtTx.wait();
  console.log(`Approved USDT: ${approveUsdtTx.hash}`);

  const deadline = Math.floor(Date.now() / 1000) + 600; // 10 minutes
  // 2% slippage tolerance on both sides, since this is the pool's first
  // deposit and the ratio we set IS the price -- there's nothing to slip
  // against yet, but the router still requires min bounds.
  const minCac = (CAC_AMOUNT * 98n) / 100n;
  const minUsdt = (USDT_AMOUNT * 98n) / 100n;

  console.log(`Adding liquidity: ${hre.ethers.formatUnits(USDT_AMOUNT, 18)} USDT + ${hre.ethers.formatUnits(CAC_AMOUNT, 18)} CAC...`);
  const addLiqTx = await router.addLiquidity(
    tokenAddress,
    USDT_ADDRESS,
    CAC_AMOUNT,
    USDT_AMOUNT,
    minCac,
    minUsdt,
    deployer.address,
    deadline
  );
  const receipt = await addLiqTx.wait();
  console.log(`Pool seeded: ${receipt.hash}`);
  console.log();
  console.log(`Verify at: https://bscscan.com/tx/${receipt.hash}`);
  console.log(`Pool page (once indexed): https://www.geckoterminal.com/bsc/pancakeswap-v2/pools`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
