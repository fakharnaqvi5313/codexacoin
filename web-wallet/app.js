import * as cac from "./crypto.js";
import { Gateway, GatewayError } from "./gateway.js";

// Production default: empty string, so Gateway's fetch(this.baseUrl + path)
// calls resolve against the page's own origin (see explorer/app.js and
// checkout-widget/checkout.js for the identical convention) -- override via
// localStorage for local dev against a gateway on a different origin/port.
const GATEWAY_URLS = {
  mainnet: localStorage.getItem("cac_gateway_url_mainnet") || "",
  testnet: localStorage.getItem("cac_gateway_url_testnet") || "",
};
const COIN = 100_000_000n;

const state = {
  network: localStorage.getItem("cac_network") || "mainnet",
  mnemonic: localStorage.getItem("cac_mnemonic") || null,
  key: null, // {privateKey, publicKey} for index 0, derived on demand
  address: null,
  gateway: null,
  stakeToken: sessionStorage.getItem("cac_stake_token") || null,
};

function refreshGateway() {
  state.gateway = new Gateway(GATEWAY_URLS[state.network]);
  document.getElementById("network-badge").textContent = state.network;
}
refreshGateway();

async function deriveActiveKey() {
  if (!state.mnemonic) return null;
  const network = cac.NETWORKS[state.network];
  state.key = await cac.deriveKey({ mnemonic: state.mnemonic, network, index: 0 });
  const hash = cac.hash160(state.key.publicKey);
  state.address = cac.p2pkhAddress(hash, network);
  return state.key;
}

function formatCac(satoshis) {
  const s = BigInt(satoshis);
  const whole = s / COIN;
  const frac = (s % COIN).toString().padStart(8, "0");
  return `${whole}.${frac}`;
}

function showScreen(name) {
  document.querySelectorAll(".screen").forEach((el) => el.classList.remove("active"));
  document.getElementById(`screen-${name}`).classList.add("active");
  document.querySelectorAll(".tabbar button").forEach((b) => b.classList.toggle("active", b.dataset.screen === name));
  if (name === "home") loadHome();
  if (name === "receive") loadReceive();
  if (name === "history") loadHistory();
  if (name === "staking") loadStaking();
}

document.querySelectorAll(".tabbar button").forEach((btn) => {
  btn.addEventListener("click", () => showScreen(btn.dataset.screen));
});

// ------------------------------------------------------------ onboarding

async function enterWallet() {
  await deriveActiveKey();
  document.getElementById("screen-onboarding").classList.remove("active");
  document.getElementById("tabbar").style.display = "flex";
  showScreen("home");
}

document.getElementById("btn-create-wallet").addEventListener("click", () => {
  const mnemonic = cac.generateMnemonic();
  document.getElementById("new-mnemonic").textContent = mnemonic;
  document.getElementById("new-mnemonic-card").style.display = "block";
  document.getElementById("btn-create-wallet").style.display = "none";
  document.getElementById("btn-show-restore").style.display = "none";
  state._pendingMnemonic = mnemonic;
});

document.getElementById("confirm-written").addEventListener("change", (e) => {
  document.getElementById("btn-mnemonic-continue").disabled = !e.target.checked;
});

document.getElementById("btn-mnemonic-continue").addEventListener("click", async () => {
  state.mnemonic = state._pendingMnemonic;
  localStorage.setItem("cac_mnemonic", state.mnemonic);
  await enterWallet();
});

document.getElementById("btn-show-restore").addEventListener("click", () => {
  document.getElementById("restore-card").style.display = "block";
});

document.getElementById("btn-restore-confirm").addEventListener("click", async () => {
  const mnemonic = document.getElementById("restore-mnemonic").value.trim();
  const errEl = document.getElementById("restore-error");
  if (!cac.isValidMnemonic(mnemonic)) {
    errEl.textContent = "Invalid recovery phrase.";
    return;
  }
  errEl.textContent = "";
  state.mnemonic = mnemonic;
  localStorage.setItem("cac_mnemonic", mnemonic);
  await enterWallet();
});

if (state.mnemonic) {
  enterWallet();
}

// -------------------------------------------------------------------- home

async function loadHome() {
  const errEl = document.getElementById("home-error");
  errEl.textContent = "";
  document.getElementById("home-address").textContent = state.address;
  try {
    const balance = await state.gateway.balance(state.address);
    const total = BigInt(balance.confirmed) + BigInt(balance.unconfirmed);
    document.getElementById("home-balance").textContent = `${formatCac(total)} CAC`;
  } catch (e) {
    errEl.textContent = e instanceof GatewayError ? e.message : `Could not reach the network: ${e}`;
  }
}

// -------------------------------------------------------------------- send

document.getElementById("btn-send-confirm").addEventListener("click", async () => {
  const errEl = document.getElementById("send-error");
  const okEl = document.getElementById("send-success");
  errEl.textContent = "";
  okEl.textContent = "";
  const toAddress = document.getElementById("send-address").value.trim();
  const amountCac = parseFloat(document.getElementById("send-amount").value);
  if (!toAddress || !amountCac || amountCac <= 0) {
    errEl.textContent = "Enter a destination address and a positive amount.";
    return;
  }
  const amountSatoshis = BigInt(Math.round(amountCac * 1e8));
  try {
    const network = cac.NETWORKS[state.network];
    const decoded = cac.decodeAddress(toAddress, network);
    let outScript;
    if (decoded.type === cac.AddressType.p2pkh) outScript = cac.p2pkhScriptPubKey(decoded.hash);
    else if (decoded.type === cac.AddressType.p2sh) outScript = cac.p2shScriptPubKey(decoded.hash);
    else outScript = cac.p2wpkhScriptPubKey(decoded.hash);

    const utxoResp = await state.gateway.utxos(state.address);
    const feeResp = await state.gateway.feeEstimate();
    const feeRate = BigInt(feeResp.fee_rate_sat_per_vbyte);
    // Rough vsize estimate for a 1-in/2-out legacy P2PKH tx (~226 bytes);
    // matches the fixed-fee-rate note in mobile-api.md section 4 -- this
    // gateway has no real dynamic fee estimation to size against precisely.
    const estimatedVsize = 226n;
    const feeSatoshis = feeRate * estimatedVsize / 1000n;

    let totalIn = 0n;
    const chosen = [];
    for (const u of utxoResp.utxos) {
      chosen.push(u);
      totalIn += BigInt(u.value);
      if (totalIn >= amountSatoshis + feeSatoshis) break;
    }
    if (totalIn < amountSatoshis + feeSatoshis) {
      errEl.textContent = `Insufficient funds: have ${formatCac(totalIn)}, need ${formatCac(amountSatoshis + feeSatoshis)}`;
      return;
    }
    const change = totalIn - amountSatoshis - feeSatoshis;
    const myHash = cac.hash160(state.key.publicKey);
    const outputs = [{ scriptPubKey: outScript, valueSatoshis: Number(amountSatoshis) }];
    if (change > 0n) outputs.push({ scriptPubKey: cac.p2pkhScriptPubKey(myHash), valueSatoshis: Number(change) });

    const inputs = chosen.map((u) => ({
      txid: cac.hexToBytes(u.txid).reverse(), // wire order is internal (reversed from display hex)
      vout: u.vout,
      valueSatoshis: Number(u.value),
      pubkeyHash: myHash,
    }));

    const rawTx = cac.buildAndSignTransaction({
      inputs, outputs, privateKey: state.key.privateKey, publicKeyCompressed: state.key.publicKey,
    });
    const result = await state.gateway.broadcast(cac.bytesToHex(rawTx));
    okEl.textContent = `Broadcast: ${result.txid}`;
    document.getElementById("send-address").value = "";
    document.getElementById("send-amount").value = "";
  } catch (e) {
    errEl.textContent = e instanceof GatewayError ? e.message : String(e);
  }
});

// ----------------------------------------------------------------- receive

function loadReceive() {
  document.getElementById("receive-address").textContent = state.address;
}
document.getElementById("btn-copy-address").addEventListener("click", () => {
  navigator.clipboard.writeText(state.address);
});

// ----------------------------------------------------------------- history

async function loadHistory() {
  const listEl = document.getElementById("history-list");
  listEl.innerHTML = '<p class="notice">Loading...</p>';
  try {
    const resp = await state.gateway.history(state.address);
    if (resp.transactions.length === 0) {
      listEl.innerHTML = '<p class="notice">No transactions yet.</p>';
      return;
    }
    listEl.innerHTML = resp.transactions
      .map((t) => `<div class="tx-row mono">${t.txid}<br><span class="notice">${t.height ? `Height ${t.height}` : "Pending"}</span></div>`)
      .join("");
  } catch (e) {
    listEl.innerHTML = `<p class="error">${e instanceof GatewayError ? e.message : "Could not reach the network."}</p>`;
  }
}

// ----------------------------------------------------------------- staking

function stakingLoggedIn() {
  return !!state.stakeToken;
}

async function loadStaking() {
  document.getElementById("staking-auth-card").style.display = stakingLoggedIn() ? "none" : "block";
  document.getElementById("staking-status-card").style.display = stakingLoggedIn() ? "block" : "none";
  document.getElementById("push-card").style.display = stakingLoggedIn() && "serviceWorker" in navigator && "PushManager" in window ? "block" : "none";
  document.getElementById("staking-actions-card").style.display = stakingLoggedIn() ? "block" : "none";
  if (!stakingLoggedIn()) return;
  try {
    const status = await state.gateway.stakingStatus(state.stakeToken);
    document.getElementById("stat-delegated").textContent = `${formatCac(status.delegated_amount)} CAC`;
    document.getElementById("stat-rewards").textContent = `${formatCac(status.accrued_rewards)} CAC`;
    document.getElementById("stat-rate").textContent = `${status.effective_monthly_rate_bp / 100}% / month`;
    document.getElementById("stat-fee").textContent = `${status.pool_fee_bp / 100}%`;
  } catch (e) {
    if (e instanceof GatewayError && e.code === "unauthorized") {
      state.stakeToken = null;
      sessionStorage.removeItem("cac_stake_token");
      loadStaking();
    }
  }
}

async function stakeAuth(action) {
  const errEl = document.getElementById("stake-auth-error");
  errEl.textContent = "";
  const email = document.getElementById("stake-email").value.trim();
  const password = document.getElementById("stake-password").value;
  try {
    let result;
    if (action === "login") {
      result = await state.gateway.login(email, password);
    } else {
      const kyc = {
        full_name: document.getElementById("stake-full-name").value.trim(),
        date_of_birth: document.getElementById("stake-dob").value,
        id_type: document.getElementById("stake-id-type").value,
        id_number: document.getElementById("stake-id-number").value.trim(),
      };
      result = await state.gateway.signup(email, password, kyc);
    }
    state.stakeToken = result.token;
    sessionStorage.setItem("cac_stake_token", result.token);
    loadStaking();
  } catch (e) {
    errEl.textContent = e instanceof GatewayError ? e.message : String(e);
  }
}
document.getElementById("btn-stake-login").addEventListener("click", () => stakeAuth("login"));
document.getElementById("btn-stake-signup").addEventListener("click", () => stakeAuth("signup"));

document.getElementById("btn-stake-deposit").addEventListener("click", async () => {
  const amountCac = parseFloat(document.getElementById("deposit-amount").value);
  const resultEl = document.getElementById("deposit-result");
  if (!amountCac || amountCac <= 0) return;
  document.getElementById("staking-action-error").textContent = "";
  try {
    const amountSatoshis = Math.round(amountCac * 1e8);
    const result = await state.gateway.stakingDeposit(state.stakeToken, amountSatoshis);
    resultEl.textContent = `Send funds to: ${result.deposit_address}`;
  } catch (e) {
    resultEl.textContent = "";
    document.getElementById("staking-action-error").textContent = e instanceof GatewayError ? e.message : String(e);
  }
});

document.getElementById("btn-stake-withdraw").addEventListener("click", async () => {
  const errEl = document.getElementById("staking-action-error");
  const okEl = document.getElementById("staking-action-success");
  errEl.textContent = "";
  okEl.textContent = "";
  const amountCac = parseFloat(document.getElementById("withdraw-amount").value);
  const toAddress = document.getElementById("withdraw-address").value.trim();
  if (!amountCac || amountCac <= 0 || !toAddress) {
    errEl.textContent = "Enter an amount and destination address.";
    return;
  }
  try {
    const amountSatoshis = Math.round(amountCac * 1e8);
    const result = await state.gateway.stakingWithdraw(state.stakeToken, amountSatoshis, toAddress);
    okEl.textContent = `Withdrawal broadcast: ${result.txid}`;
    loadStaking();
  } catch (e) {
    errEl.textContent = e instanceof GatewayError ? e.message : String(e);
  }
});

// ------------------------------------------------------------ web push

// Converts the VAPID public key from the base64url encoding the Web
// Push spec transmits it in to the raw Uint8Array PushManager.subscribe
// actually wants.
function urlBase64ToUint8Array(base64url) {
  const padding = "=".repeat((4 - (base64url.length % 4)) % 4);
  const base64 = (base64url + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)));
}

document.getElementById("btn-enable-push").addEventListener("click", async () => {
  const errEl = document.getElementById("push-error");
  const okEl = document.getElementById("push-success");
  errEl.textContent = "";
  okEl.textContent = "";
  try {
    const permission = await Notification.requestPermission();
    if (permission !== "granted") {
      errEl.textContent = "Notification permission was not granted.";
      return;
    }
    const { public_key: vapidPublicKey } = await state.gateway.pushVapidPublicKey();
    const registration = await navigator.serviceWorker.register("./sw.js");
    await navigator.serviceWorker.ready;
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      });
    }
    await state.gateway.pushSubscribe(state.stakeToken, subscription.toJSON());
    okEl.textContent = "Notifications enabled.";
  } catch (e) {
    errEl.textContent = e instanceof GatewayError ? e.message : String(e);
  }
});

// ---------------------------------------------------------------- settings

function switchNetwork(net) {
  state.network = net;
  localStorage.setItem("cac_network", net);
  refreshGateway();
  deriveActiveKey();
}
document.getElementById("btn-net-mainnet").addEventListener("click", () => switchNetwork("mainnet"));
document.getElementById("btn-net-testnet").addEventListener("click", () => switchNetwork("testnet"));

document.getElementById("btn-wipe-wallet").addEventListener("click", () => {
  if (!confirm("This deletes your recovery phrase from this browser. If you have not backed it up, any funds will be permanently unrecoverable. Continue?")) return;
  localStorage.removeItem("cac_mnemonic");
  sessionStorage.removeItem("cac_stake_token");
  location.reload();
});
