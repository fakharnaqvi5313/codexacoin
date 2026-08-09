import * as cac from "./crypto.js";
import { Gateway, GatewayError } from "./gateway.js";
import * as qr from "./qr.js";
import * as storage from "./storage.js";

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
  mnemonic: null, // decrypted in-memory only once unlocked; never re-persisted in plain text if a PIN is set
  addressIndices: [], // every address index this wallet has generated on this browser, this network
  activeIndex: 0, // which index is shown as "current" on Receive / used for change outputs
  keys: {}, // index -> {privateKey, publicKey}
  addresses: {}, // index -> address string
  gateway: null,
  stakeToken: sessionStorage.getItem("cac_stake_token") || null,
  qrScanHandle: null,
};

function refreshGateway() {
  state.gateway = new Gateway(GATEWAY_URLS[state.network]);
  document.getElementById("network-badge").textContent = state.network;
}
refreshGateway();

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

function formatCac(satoshis) {
  const s = BigInt(satoshis);
  const whole = s / COIN;
  const frac = (s % COIN).toString().padStart(8, "0");
  return `${whole}.${frac}`;
}

// ------------------------------------------------------------- addresses

function addressIndicesStorageKey() {
  return `cac_address_indices_${state.network}`;
}
function loadAddressIndices() {
  const raw = localStorage.getItem(addressIndicesStorageKey());
  const parsed = raw ? JSON.parse(raw) : null;
  return parsed && parsed.length ? parsed : [0];
}
function saveAddressIndices() {
  localStorage.setItem(addressIndicesStorageKey(), JSON.stringify(state.addressIndices));
}

async function ensureKey(index) {
  if (state.keys[index]) return state.keys[index];
  const network = cac.NETWORKS[state.network];
  const key = await cac.deriveKey({ mnemonic: state.mnemonic, network, index });
  state.keys[index] = key;
  state.addresses[index] = cac.p2pkhAddress(cac.hash160(key.publicKey), network);
  return key;
}

// Derives every address this wallet has generated so far on this browser
// for the current network. This is *not* BIP44 gap-limit discovery --
// it only knows about indices this browser itself has generated (via
// "New address" on the Receive screen), tracked locally in localStorage.
// A phrase restored fresh on a new browser starts back at just index 0;
// it does not scan for addresses used elsewhere. Balance, UTXOs, and
// history are combined across every known index.
async function deriveAllKnownAddresses() {
  state.addressIndices = loadAddressIndices();
  for (const idx of state.addressIndices) await ensureKey(idx);
  if (!state.addressIndices.includes(state.activeIndex)) {
    state.activeIndex = state.addressIndices[state.addressIndices.length - 1];
  }
}

function activeAddress() {
  return state.addresses[state.activeIndex];
}

async function gatherAllUtxos() {
  const all = [];
  for (const idx of state.addressIndices) {
    const resp = await state.gateway.utxos(state.addresses[idx]);
    for (const u of resp.utxos) all.push({ ...u, _index: idx });
  }
  return all;
}

// ------------------------------------------------------------- screens

function showScreen(name) {
  document.querySelectorAll(".screen").forEach((el) => el.classList.remove("active"));
  document.getElementById(`screen-${name}`).classList.add("active");
  document.querySelectorAll(".tabbar button").forEach((b) => b.classList.toggle("active", b.dataset.screen === name));
  if (name === "home") loadHome();
  if (name === "send") loadAddressBook();
  if (name === "receive") loadReceive();
  if (name === "history") loadHistory();
  if (name === "staking") loadStaking();
  if (name === "multisig") loadMultisig();
  if (name === "settings") loadSettings();
}

document.querySelectorAll(".tabbar button").forEach((btn) => {
  btn.addEventListener("click", () => showScreen(btn.dataset.screen));
});

// ------------------------------------------------------------ onboarding

async function enterWallet() {
  await deriveAllKnownAddresses();
  document.getElementById("screen-onboarding").classList.remove("active");
  document.getElementById("lock-overlay").style.display = "none";
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
  state.addressIndices = [0];
  saveAddressIndices();
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
  state.addressIndices = [0];
  saveAddressIndices();
  await enterWallet();
});

// ------------------------------------------------------------- app lock

async function boot() {
  if (storage.isPinSet()) {
    document.getElementById("lock-overlay").style.display = "flex";
    return;
  }
  state.mnemonic = localStorage.getItem("cac_mnemonic") || null;
  if (state.mnemonic) await enterWallet();
}
boot();

document.getElementById("btn-unlock").addEventListener("click", async () => {
  const pin = document.getElementById("lock-pin").value;
  const errEl = document.getElementById("lock-error");
  errEl.textContent = "";
  try {
    const blob = storage.loadEncryptedBlob();
    state.mnemonic = await storage.decryptMnemonic(blob, pin);
    document.getElementById("lock-pin").value = "";
    await enterWallet();
  } catch (e) {
    errEl.textContent = "Incorrect PIN.";
  }
});
document.getElementById("lock-pin").addEventListener("keydown", (e) => {
  if (e.key === "Enter") document.getElementById("btn-unlock").click();
});

// -------------------------------------------------------------------- home

async function loadHome() {
  const errEl = document.getElementById("home-error");
  errEl.textContent = "";
  document.getElementById("home-address").textContent = activeAddress();
  document.getElementById("home-address-count").textContent =
    state.addressIndices.length > 1 ? `Balance combined across ${state.addressIndices.length} addresses` : "";
  try {
    let total = 0n;
    for (const idx of state.addressIndices) {
      const balance = await state.gateway.balance(state.addresses[idx]);
      total += BigInt(balance.confirmed) + BigInt(balance.unconfirmed);
    }
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

    const allUtxos = await gatherAllUtxos();
    const feeResp = await state.gateway.feeEstimate();
    const feeRate = BigInt(feeResp.fee_rate_sat_per_vbyte);

    let totalIn = 0n;
    const chosen = [];
    for (const u of allUtxos) {
      chosen.push(u);
      totalIn += BigInt(u.value);
      // Re-estimated as inputs accumulate, scaled by input count -- rougher
      // than real dynamic fee estimation (this gateway has none, a known
      // limitation noted in mobile-api.md section 4), but a fixed 226-byte
      // guess stopped being reasonable once a send can span more than one
      // address's UTXOs.
      const estimatedVsize = BigInt(10 + chosen.length * 148 + 2 * 34);
      const feeSatoshis = (feeRate * estimatedVsize) / 1000n;
      if (totalIn >= amountSatoshis + feeSatoshis) break;
    }
    const finalVsize = BigInt(10 + chosen.length * 148 + 2 * 34);
    const feeSatoshis = (feeRate * finalVsize) / 1000n;
    if (totalIn < amountSatoshis + feeSatoshis) {
      errEl.textContent = `Insufficient funds: have ${formatCac(totalIn)}, need ${formatCac(amountSatoshis + feeSatoshis)}`;
      return;
    }
    const change = totalIn - amountSatoshis - feeSatoshis;
    const changeKey = await ensureKey(state.activeIndex);
    const changeHash = cac.hash160(changeKey.publicKey);
    const outputs = [{ scriptPubKey: outScript, valueSatoshis: Number(amountSatoshis) }];
    if (change > 0n) outputs.push({ scriptPubKey: cac.p2pkhScriptPubKey(changeHash), valueSatoshis: Number(change) });

    const inputs = chosen.map((u) => {
      const key = state.keys[u._index];
      return {
        txid: cac.hexToBytes(u.txid).reverse(), // wire order is internal (reversed from display hex)
        vout: u.vout,
        valueSatoshis: Number(u.value),
        pubkeyHash: cac.hash160(key.publicKey),
        privateKey: key.privateKey,
        publicKeyCompressed: key.publicKey,
      };
    });

    const rawTx = cac.buildAndSignTransaction({ inputs, outputs });
    const result = await state.gateway.broadcast(cac.bytesToHex(rawTx));
    okEl.textContent = `Broadcast: ${result.txid}`;
    document.getElementById("send-address").value = "";
    document.getElementById("send-amount").value = "";
  } catch (e) {
    errEl.textContent = e instanceof GatewayError ? e.message : String(e);
  }
});

// ------------------------------------------------------------- QR scanning

document.getElementById("btn-scan-qr").addEventListener("click", () => {
  document.getElementById("qr-scan-overlay").style.display = "flex";
  document.getElementById("qr-scan-error").textContent = "";
  const video = document.getElementById("qr-video");
  const canvas = document.getElementById("qr-scan-canvas");
  state.qrScanHandle = qr.startQrScanner({
    video,
    canvas,
    onResult: (text) => {
      document.getElementById("send-address").value = text;
      closeQrScan();
    },
    onError: () => {
      document.getElementById("qr-scan-error").textContent =
        "Could not access the camera. Check that this site has camera permission in your browser settings.";
    },
  });
});
function closeQrScan() {
  if (state.qrScanHandle) state.qrScanHandle.stop();
  state.qrScanHandle = null;
  document.getElementById("qr-scan-overlay").style.display = "none";
  document.getElementById("qr-video").srcObject = null;
}
document.getElementById("btn-qr-scan-cancel").addEventListener("click", closeQrScan);

// -------------------------------------------------------------- address book

function loadAddressBookEntries() {
  const raw = localStorage.getItem("cac_address_book");
  return raw ? JSON.parse(raw) : [];
}
function saveAddressBookEntries(entries) {
  localStorage.setItem("cac_address_book", JSON.stringify(entries));
}
function renderAddressBook() {
  const entries = loadAddressBookEntries();
  const listEl = document.getElementById("address-book-list");
  if (entries.length === 0) {
    listEl.innerHTML = '<p class="notice">No saved addresses yet.</p>';
    return;
  }
  listEl.innerHTML = entries
    .map(
      (e, i) => `
    <div class="book-row">
      <div class="book-info">
        <div class="book-label">${escapeHtml(e.label)}</div>
        <div class="book-address mono">${escapeHtml(e.address)}</div>
      </div>
      <button class="secondary" type="button" data-use="${i}">Use</button>
      <button class="danger" type="button" data-remove="${i}">Remove</button>
    </div>`
    )
    .join("");
  listEl.querySelectorAll("[data-use]").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.getElementById("send-address").value = entries[Number(btn.dataset.use)].address;
    });
  });
  listEl.querySelectorAll("[data-remove]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = Number(btn.dataset.remove);
      const updated = loadAddressBookEntries();
      updated.splice(idx, 1);
      saveAddressBookEntries(updated);
      renderAddressBook();
    });
  });
}
function loadAddressBook() {
  renderAddressBook();
}
document.getElementById("btn-book-add").addEventListener("click", () => {
  const label = document.getElementById("new-book-label").value.trim();
  const address = document.getElementById("new-book-address").value.trim();
  if (!label || !address) return;
  const entries = loadAddressBookEntries();
  entries.push({ label, address });
  saveAddressBookEntries(entries);
  document.getElementById("new-book-label").value = "";
  document.getElementById("new-book-address").value = "";
  renderAddressBook();
});

// ----------------------------------------------------------------- receive

async function loadReceive() {
  document.getElementById("receive-address").textContent = activeAddress();
  await qr.renderQr(document.getElementById("receive-qr"), activeAddress());
  renderAddressList();
}
function renderAddressList() {
  const listEl = document.getElementById("address-list");
  listEl.innerHTML = state.addressIndices
    .map(
      (idx) => `
    <div class="addr-row ${idx === state.activeIndex ? "current" : ""}">
      <span class="mono addr-info">${state.addresses[idx]}</span>
      <button class="secondary" type="button" data-select="${idx}">${idx === state.activeIndex ? "Current" : "Use"}</button>
    </div>`
    )
    .join("");
  listEl.querySelectorAll("[data-select]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      state.activeIndex = Number(btn.dataset.select);
      await loadReceive();
    });
  });
}
document.getElementById("btn-new-address").addEventListener("click", async () => {
  const nextIndex = Math.max(...state.addressIndices) + 1;
  state.addressIndices.push(nextIndex);
  saveAddressIndices();
  await ensureKey(nextIndex);
  state.activeIndex = nextIndex;
  await loadReceive();
});
document.getElementById("btn-copy-address").addEventListener("click", () => {
  navigator.clipboard.writeText(activeAddress());
});

// ----------------------------------------------------------------- history

async function loadHistory() {
  const listEl = document.getElementById("history-list");
  listEl.innerHTML = '<p class="notice">Loading...</p>';
  try {
    const seen = new Set();
    const allTxs = [];
    for (const idx of state.addressIndices) {
      const resp = await state.gateway.history(state.addresses[idx]);
      for (const t of resp.transactions) {
        if (seen.has(t.txid)) continue;
        seen.add(t.txid);
        allTxs.push(t);
      }
    }
    if (allTxs.length === 0) {
      listEl.innerHTML = '<p class="notice">No transactions yet.</p>';
      return;
    }
    allTxs.sort((a, b) => (b.height ?? Infinity) - (a.height ?? Infinity));
    listEl.innerHTML = allTxs
      .map(
        (t) =>
          `<div class="tx-row mono" data-txid="${t.txid}">${t.txid}<br><span class="notice">${t.height ? `Height ${t.height}` : "Pending"}</span></div>`
      )
      .join("");
    listEl.querySelectorAll(".tx-row").forEach((row) => {
      row.addEventListener("click", () => openTxDetail(row.dataset.txid));
    });
  } catch (e) {
    listEl.innerHTML = `<p class="error">${e instanceof GatewayError ? e.message : "Could not reach the network."}</p>`;
  }
}

async function openTxDetail(txid) {
  document.getElementById("tx-detail-overlay").style.display = "flex";
  const bodyEl = document.getElementById("tx-detail-body");
  bodyEl.innerHTML = '<p class="notice">Loading...</p>';
  try {
    const tx = await state.gateway.tx(txid);
    const rows = [];
    rows.push(["Txid", tx.txid]);
    rows.push(["Status", tx.height ? `Confirmed, height ${tx.height} (${tx.confirmations} confirmations)` : "Pending"]);
    if (tx.is_coinstake && tx.reward_satoshis != null) {
      rows.push(["Type", "Staking reward (coinstake)"]);
      rows.push(["Reward", `${formatCac(tx.reward_satoshis)} CAC`]);
    }
    for (const vin of tx.vin) {
      rows.push(["Input", vin.coinbase ? "coinbase" : `${vin.txid.slice(0, 16)}...:${vin.vout}`]);
    }
    for (const vout of tx.vout) {
      const addr = vout.scriptPubKey?.address || vout.scriptPubKey?.addresses?.[0] || "(non-standard output)";
      rows.push(["Output", `${addr}: ${vout.value} CAC`]);
    }
    bodyEl.innerHTML = rows
      .map(([k, v]) => `<div class="kv-row"><span>${escapeHtml(k)}</span><span class="mono">${escapeHtml(String(v))}</span></div>`)
      .join("");
  } catch (e) {
    bodyEl.innerHTML = `<p class="error">${e instanceof GatewayError ? e.message : "Could not load transaction."}</p>`;
  }
}
document.getElementById("btn-tx-detail-close").addEventListener("click", () => {
  document.getElementById("tx-detail-overlay").style.display = "none";
});

// ----------------------------------------------------------------- staking

function stakingLoggedIn() {
  return !!state.stakeToken;
}

async function loadStaking() {
  document.getElementById("staking-auth-card").style.display = stakingLoggedIn() ? "none" : "block";
  document.getElementById("staking-status-card").style.display = stakingLoggedIn() ? "block" : "none";
  document.getElementById("push-card").style.display = stakingLoggedIn() && "serviceWorker" in navigator && "PushManager" in window ? "block" : "none";
  document.getElementById("staking-actions-card").style.display = stakingLoggedIn() ? "block" : "none";
  document.getElementById("referral-card").style.display = stakingLoggedIn() ? "block" : "none";
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
      return;
    }
  }
  try {
    const ref = await state.gateway.referralStatus(state.stakeToken);
    document.getElementById("stat-referral-code").textContent = ref.referral_code;
    document.getElementById("stat-referral-count").textContent = ref.referred_count;
    document.getElementById("stat-referral-available").textContent = `${formatCac(ref.available_satoshis)} CAC`;
  } catch (e) {
    // Non-fatal -- staking status above already handles auth expiry; a
    // referral-status hiccup shouldn't block the rest of the screen.
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
        referral_code: document.getElementById("stake-referral-code").value.trim(),
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

document.getElementById("btn-referral-withdraw").addEventListener("click", async () => {
  const errEl = document.getElementById("referral-action-error");
  const okEl = document.getElementById("referral-action-success");
  errEl.textContent = "";
  okEl.textContent = "";
  const toAddress = document.getElementById("referral-withdraw-address").value.trim();
  if (!toAddress) {
    errEl.textContent = "Enter a destination address.";
    return;
  }
  try {
    const result = await state.gateway.referralWithdraw(state.stakeToken, toAddress);
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

// ----------------------------------------------------------------- multisig
//
// UI on top of crypto.js's already-complete multisig primitives (see the
// comment above createMultisigRedeemScript there). Proposals are signed
// sequentially -- cosigner A signs the pasted-in JSON, copies the result
// to cosigner B, B pastes and signs the same object, and so on -- which
// is enough to reach any m-of-n threshold without needing an explicit
// "combine independently-signed copies" step (crypto.js's
// mergeMultisigProposals exists for that parallel-signing case but isn't
// wired into this UI; a deliberate scope cut, not an oversight).
//
// Index 0's key is used as this wallet's multisig identity, regardless of
// which address is "active" on the Receive screen -- a cosigner set
// should be built against a stable key, not one that changes every time
// someone taps "New address".

async function loadMultisig() {
  const key = await ensureKey(0);
  document.getElementById("my-pubkey").textContent = cac.bytesToHex(key.publicKey);
}

document.getElementById("btn-ms-create").addEventListener("click", async () => {
  const errEl = document.getElementById("ms-create-error");
  errEl.textContent = "";
  document.getElementById("ms-create-result").style.display = "none";
  try {
    const key = await ensureKey(0);
    const lines = document
      .getElementById("ms-pubkeys")
      .value.trim()
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean);
    const cosignerPubkeys = lines.map((hex) => cac.hexToBytes(hex));
    const allPubkeys = [key.publicKey, ...cosignerPubkeys];
    const m = parseInt(document.getElementById("ms-m").value, 10);
    const redeemScript = cac.createMultisigRedeemScript(m, allPubkeys);
    const network = cac.NETWORKS[state.network];
    const address = cac.multisigAddress(redeemScript, network);
    document.getElementById("ms-redeem-script").textContent = cac.bytesToHex(redeemScript);
    document.getElementById("ms-address").textContent = address;
    document.getElementById("ms-create-result").style.display = "block";
    document.getElementById("ms-propose-address").value = address;
    document.getElementById("ms-propose-redeem").value = cac.bytesToHex(redeemScript);
  } catch (e) {
    errEl.textContent = String(e.message || e);
  }
});

document.getElementById("btn-ms-propose").addEventListener("click", async () => {
  const errEl = document.getElementById("ms-propose-error");
  errEl.textContent = "";
  try {
    const address = document.getElementById("ms-propose-address").value.trim();
    const redeemScriptHex = document.getElementById("ms-propose-redeem").value.trim();
    const toAddress = document.getElementById("ms-propose-to").value.trim();
    const amountCac = parseFloat(document.getElementById("ms-propose-amount").value);
    if (!address || !redeemScriptHex || !toAddress || !amountCac || amountCac <= 0) {
      errEl.textContent = "Fill in every field.";
      return;
    }
    const redeemScript = cac.hexToBytes(redeemScriptHex);
    const network = cac.NETWORKS[state.network];
    const decoded = cac.decodeAddress(toAddress, network);
    let outScript;
    if (decoded.type === cac.AddressType.p2pkh) outScript = cac.p2pkhScriptPubKey(decoded.hash);
    else if (decoded.type === cac.AddressType.p2sh) outScript = cac.p2shScriptPubKey(decoded.hash);
    else outScript = cac.p2wpkhScriptPubKey(decoded.hash);
    const amountSatoshis = BigInt(Math.round(amountCac * 1e8));

    const utxoResp = await state.gateway.utxos(address);
    const feeResp = await state.gateway.feeEstimate();
    const feeRate = BigInt(feeResp.fee_rate_sat_per_vbyte);

    let totalIn = 0n;
    const chosen = [];
    for (const u of utxoResp.utxos) {
      chosen.push(u);
      totalIn += BigInt(u.value);
      // Multisig scriptSigs run much larger than a plain P2PKH spend (one
      // DER signature per required cosigner, plus the redeem script
      // itself pushed in full) -- deliberately generous rather than
      // precise, the same "no real dynamic fee estimation" limitation
      // noted for the ordinary send flow above.
      const estimatedVsize = BigInt(10 + chosen.length * (redeemScript.length + 150) + 2 * 34);
      const feeSatoshis = (feeRate * estimatedVsize) / 1000n;
      if (totalIn >= amountSatoshis + feeSatoshis) break;
    }
    const finalVsize = BigInt(10 + chosen.length * (redeemScript.length + 150) + 2 * 34);
    const feeSatoshis = (feeRate * finalVsize) / 1000n;
    if (totalIn < amountSatoshis + feeSatoshis) {
      errEl.textContent = `Insufficient funds at this address: have ${formatCac(totalIn)}, need ${formatCac(amountSatoshis + feeSatoshis)}`;
      return;
    }
    const change = totalIn - amountSatoshis - feeSatoshis;
    const outputs = [{ scriptPubKey: outScript, valueSatoshis: Number(amountSatoshis) }];
    if (change > 0n) outputs.push({ scriptPubKey: cac.p2shScriptPubKey(cac.hash160(redeemScript)), valueSatoshis: Number(change) });

    const inputs = chosen.map((u) => ({
      txid: cac.hexToBytes(u.txid).reverse(),
      vout: u.vout,
      valueSatoshis: Number(u.value),
      redeemScript,
    }));
    const proposal = cac.createMultisigProposal({ inputs, outputs });
    document.getElementById("ms-proposal-json").value = JSON.stringify(proposal, null, 2);
  } catch (e) {
    errEl.textContent = String(e.message || e);
  }
});

document.getElementById("btn-ms-sign").addEventListener("click", async () => {
  const errEl = document.getElementById("ms-sign-error");
  const okEl = document.getElementById("ms-sign-success");
  errEl.textContent = "";
  okEl.textContent = "";
  try {
    const key = await ensureKey(0);
    const proposal = JSON.parse(document.getElementById("ms-proposal-json").value);
    cac.signMultisigProposal(proposal, key.privateKey, key.publicKey);
    document.getElementById("ms-proposal-json").value = JSON.stringify(proposal, null, 2);
    okEl.textContent = "Signed with your key. Send this JSON to the next cosigner, or finalize if enough signatures are collected.";
  } catch (e) {
    errEl.textContent = String(e.message || e);
  }
});

document.getElementById("btn-ms-broadcast").addEventListener("click", async () => {
  const errEl = document.getElementById("ms-sign-error");
  const okEl = document.getElementById("ms-sign-success");
  errEl.textContent = "";
  okEl.textContent = "";
  try {
    const proposal = JSON.parse(document.getElementById("ms-proposal-json").value);
    const rawTx = cac.finalizeMultisigTransaction(proposal);
    const result = await state.gateway.broadcast(cac.bytesToHex(rawTx));
    okEl.textContent = `Broadcast: ${result.txid}`;
  } catch (e) {
    errEl.textContent = e instanceof GatewayError ? e.message : String(e.message || e);
  }
});

// ---------------------------------------------------------------- settings

// Called both when the Settings screen is freshly entered (clears any
// stale message from a previous visit) and after set/remove-PIN actions
// (must NOT clear the message those actions just set -- see
// refreshLockCardVisibility for the action-safe version of this).
function loadSettings() {
  refreshLockCardVisibility();
  document.getElementById("lock-settings-error").textContent = "";
  document.getElementById("lock-settings-success").textContent = "";
}
function refreshLockCardVisibility() {
  const pinSet = storage.isPinSet();
  document.getElementById("lock-not-set").style.display = pinSet ? "none" : "block";
  document.getElementById("lock-is-set").style.display = pinSet ? "block" : "none";
}

document.getElementById("btn-set-pin").addEventListener("click", async () => {
  const errEl = document.getElementById("lock-settings-error");
  const okEl = document.getElementById("lock-settings-success");
  errEl.textContent = "";
  okEl.textContent = "";
  const pin = document.getElementById("set-pin").value;
  const confirmPin = document.getElementById("set-pin-confirm").value;
  if (pin.length < 4) {
    errEl.textContent = "PIN must be at least 4 characters.";
    return;
  }
  if (pin !== confirmPin) {
    errEl.textContent = "PINs don't match.";
    return;
  }
  await storage.setPin(state.mnemonic, pin);
  document.getElementById("set-pin").value = "";
  document.getElementById("set-pin-confirm").value = "";
  okEl.textContent = "PIN set. Your recovery phrase is now encrypted at rest.";
  refreshLockCardVisibility();
});

document.getElementById("btn-lock-now").addEventListener("click", () => {
  state.mnemonic = null;
  state.keys = {};
  state.addresses = {};
  document.getElementById("tabbar").style.display = "none";
  document.querySelectorAll(".screen").forEach((el) => el.classList.remove("active"));
  document.getElementById("lock-overlay").style.display = "flex";
});

document.getElementById("btn-remove-pin").addEventListener("click", () => {
  storage.removePin(state.mnemonic);
  document.getElementById("lock-settings-success").textContent = "PIN removed; recovery phrase is now stored in plain text.";
  document.getElementById("lock-settings-error").textContent = "";
  refreshLockCardVisibility();
});

async function switchNetwork(net) {
  state.network = net;
  localStorage.setItem("cac_network", net);
  refreshGateway();
  state.keys = {};
  state.addresses = {};
  await deriveAllKnownAddresses();
  showScreen("home");
}
document.getElementById("btn-net-mainnet").addEventListener("click", () => switchNetwork("mainnet"));
document.getElementById("btn-net-testnet").addEventListener("click", () => switchNetwork("testnet"));

document.getElementById("btn-wipe-wallet").addEventListener("click", () => {
  if (!confirm("This deletes your recovery phrase from this browser. If you have not backed it up, any funds will be permanently unrecoverable. Continue?")) return;
  localStorage.removeItem("cac_mnemonic");
  localStorage.removeItem("cac_mnemonic_encrypted");
  localStorage.removeItem("cac_address_indices_mainnet");
  localStorage.removeItem("cac_address_indices_testnet");
  localStorage.removeItem("cac_address_book");
  sessionStorage.removeItem("cac_stake_token");
  location.reload();
});
