// Production default: empty string, so fetch() calls below (each of
// which already includes the "/api/..." prefix itself, e.g. "/api/stats")
// resolve same-origin. Meant to be reverse-proxied that way (see
// ../provisioning/explorer/nginx-example.conf) so the frontend and
// backend share an origin and need no CORS setup at all. Local
// development runs them on different ports (see README.md) -- override
// via localStorage to a full origin like "http://127.0.0.1:8081" for
// that case, which is why CORS is still supported/enabled on the backend.
const API_BASE = localStorage.getItem("cac_explorer_api") || "";
const COIN = 100_000_000n;

function formatCac(satoshis) {
  const s = BigInt(satoshis);
  const whole = s / COIN;
  const frac = (s % COIN).toString().padStart(8, "0");
  return `${whole}.${frac}`;
}

function formatTime(unixSeconds) {
  if (!unixSeconds) return "-";
  return new Date(unixSeconds * 1000).toISOString().replace("T", " ").replace(".000Z", " UTC");
}

function shorten(hash, n = 10) {
  if (!hash) return "-";
  return hash.length > n * 2 ? `${hash.slice(0, n)}…${hash.slice(-n)}` : hash;
}

async function api(path) {
  const resp = await fetch(API_BASE + path);
  const data = await resp.json();
  if (!resp.ok) throw new Error(data.error || `Request failed (${resp.status})`);
  return data;
}

const app = document.getElementById("app");

function render(html) {
  app.innerHTML = html;
}

function renderError(message) {
  render(`<div class="card error">${message}</div>`);
}

// ------------------------------------------------------------------ home

let homeRefreshTimer = null;
const HOME_REFRESH_MS = 20000;

function supplyChartSvg(points) {
  if (points.length < 2) return "";
  const w = 600, h = 140, pad = 8;
  const maxHeight = points[points.length - 1].height || 1;
  const maxSupply = BigInt(points[points.length - 1].minted_satoshis) || 1n;
  const coords = points.map((p) => {
    const x = pad + (p.height / maxHeight) * (w - 2 * pad);
    const frac = maxSupply > 0n ? Number((BigInt(p.minted_satoshis) * 1000n) / maxSupply) / 1000 : 0;
    const y = h - pad - frac * (h - 2 * pad);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  });
  return `
    <svg viewBox="0 0 ${w} ${h}" style="width:100%;height:${h}px;">
      <polyline points="${coords.join(" ")}" fill="none" stroke="#f0c350" stroke-width="2" />
    </svg>`;
}

async function renderHome() {
  if (homeRefreshTimer) { clearInterval(homeRefreshTimer); homeRefreshTimer = null; }
  render('<div class="notice">Loading...</div>');
  try {
    const [stats, supply] = await Promise.all([api("/api/stats"), api("/api/supply-series")]);
    const powProgress = `${stats.pow_blocks_mined} / ${stats.pow_window_blocks}`;
    render(`
      <div class="stats-grid">
        <div class="stat-tile"><div class="label">Height</div><div class="value">${stats.height}</div></div>
        <div class="stat-tile"><div class="label">Difficulty</div><div class="value">${Number(stats.difficulty).toPrecision(4)}</div></div>
        <div class="stat-tile"><div class="label">Premine window</div><div class="value">${powProgress}</div></div>
        <div class="stat-tile"><div class="label">Phase</div><div class="value">${stats.pow_phase_complete ? "PoS" : "PoW premine"}</div></div>
      </div>
      <div class="card">
        <div class="detail-row"><span class="k">Best block</span><span class="v mono"><a href="#/block/${stats.best_block_hash}">${shorten(stats.best_block_hash)}</a></span></div>
        <div class="detail-row"><span class="k">Chain</span><span class="v">${stats.chain}</span></div>
        <div class="detail-row"><span class="k">Minted from PoW window so far</span><span class="v">${formatCac(stats.minted_from_pow_satoshis)} CAC</span></div>
        <div class="detail-row"><span class="k">Total premine (full window)</span><span class="v">${formatCac(stats.premine_total_satoshis)} CAC</span></div>
      </div>
      <div class="card">
        <h3 style="margin-top:0">Supply minted (PoW window)</h3>
        ${supplyChartSvg(supply.points)}
        <p class="notice">${supply.note}</p>
      </div>
      <div class="card">
        <a href="#/richlist">View rich list &rarr;</a>
      </div>
      <div class="card">
        <p class="notice">Enter a block height, block hash, transaction id, or address above to look it up.
        This page auto-refreshes every ${HOME_REFRESH_MS / 1000}s.</p>
      </div>
    `);
    homeRefreshTimer = setInterval(() => {
      if (location.hash === "" || location.hash === "#/") renderHome();
    }, HOME_REFRESH_MS);
  } catch (e) {
    renderError(e.message);
  }
}

// --------------------------------------------------------------- richlist

async function renderRichlist() {
  render('<div class="notice">Loading (this scans recent blocks, may take a moment)...</div>');
  try {
    const data = await api("/api/richlist?limit=25");
    render(`
      <div class="card">
        <h2 style="margin-top:0">Rich list</h2>
        <p class="notice">Computed from blocks ${data.scanned_from_height}&ndash;${data.scanned_to_height}${data.truncated ? " (older history not included -- see API note)" : ""}.</p>
        <table>
          <thead><tr><th>#</th><th>Address</th><th>Balance</th></tr></thead>
          <tbody>
            ${data.addresses.map((a, i) => `
              <tr>
                <td>${i + 1}</td>
                <td class="mono"><a href="#/address/${a.address}">${shorten(a.address, 14)}</a></td>
                <td>${formatCac(a.balance_satoshis)} CAC</td>
              </tr>`).join("")}
          </tbody>
        </table>
      </div>
    `);
  } catch (e) {
    renderError(e.message);
  }
}

// ----------------------------------------------------------------- block

async function renderBlock(ident) {
  render('<div class="notice">Loading...</div>');
  try {
    const b = await api(`/api/block/${ident}`);
    const badge = b.is_proof_of_stake ? '<span class="badge pos">PoS</span>' : '<span class="badge pow">PoW</span>';
    render(`
      <div class="card">
        <h2 style="margin-top:0">Block ${b.height} ${badge}</h2>
        <div class="detail-row"><span class="k">Hash</span><span class="v mono">${b.hash}</span></div>
        <div class="detail-row"><span class="k">Time</span><span class="v">${formatTime(b.time)}</span></div>
        <div class="detail-row"><span class="k">Difficulty</span><span class="v">${b.difficulty}</span></div>
        <div class="detail-row"><span class="k">Bits</span><span class="v mono">${b.bits}</span></div>
        <div class="detail-row"><span class="k">Merkle root</span><span class="v mono">${shorten(b.merkleroot)}</span></div>
        <div class="detail-row"><span class="k">Previous block</span><span class="v mono">${b.previousblockhash ? `<a href="#/block/${b.previousblockhash}">${shorten(b.previousblockhash)}</a>` : "-"}</span></div>
        <div class="detail-row"><span class="k">Next block</span><span class="v mono">${b.nextblockhash ? `<a href="#/block/${b.nextblockhash}">${shorten(b.nextblockhash)}</a>` : "(tip)"}</span></div>
      </div>
      <div class="card">
        <h3 style="margin-top:0">Transactions (${b.tx_count})</h3>
        <table>
          <thead><tr><th>Txid</th><th>Type</th><th>Outputs</th></tr></thead>
          <tbody>
            ${b.transactions.map((t) => `
              <tr>
                <td class="mono"><a href="#/tx/${t.txid}">${shorten(t.txid)}</a></td>
                <td>${t.is_coinbase ? '<span class="badge coinbase">coinbase</span>' : t.is_coinstake ? '<span class="badge pos">coinstake</span>' : "transfer"}</td>
                <td>${formatCac(t.output_total_satoshis)} CAC</td>
              </tr>`).join("")}
          </tbody>
        </table>
      </div>
    `);
  } catch (e) {
    renderError(e.message);
  }
}

// -------------------------------------------------------------------- tx

async function renderTx(txid) {
  render('<div class="notice">Loading...</div>');
  try {
    const t = await api(`/api/tx/${txid}`);
    const typeBadge = t.is_coinbase
      ? '<span class="badge coinbase">coinbase</span>'
      : t.is_coinstake
        ? '<span class="badge pos">coinstake</span>'
        : "transfer";
    render(`
      <div class="card">
        <h2 style="margin-top:0">Transaction ${typeBadge}</h2>
        <div class="detail-row"><span class="k">Txid</span><span class="v mono">${t.txid}</span></div>
        <div class="detail-row"><span class="k">Block</span><span class="v">${t.height !== null ? `<a href="#/block/${t.blockhash}">${t.height}</a>` : "unconfirmed"}</span></div>
        <div class="detail-row"><span class="k">Confirmations</span><span class="v">${t.confirmations}</span></div>
        <div class="detail-row"><span class="k">Time</span><span class="v">${formatTime(t.time)}</span></div>
        ${t.reward_satoshis !== null ? `<div class="detail-row"><span class="k">Staking reward</span><span class="v">${formatCac(t.reward_satoshis)} CAC</span></div>` : ""}
      </div>
      <div class="card">
        <h3 style="margin-top:0">Inputs (${t.vin.length})</h3>
        ${t.vin.map((vin) => vin.coinbase
          ? `<div class="detail-row"><span class="k">Coinbase</span><span class="v mono">${vin.coinbase}</span></div>`
          : `<div class="detail-row"><span class="k mono">${shorten(vin.txid)}:${vin.vout}</span><span class="v"></span></div>`
        ).join("")}
      </div>
      <div class="card">
        <h3 style="margin-top:0">Outputs (${t.vout.length})</h3>
        ${t.vout.map((vout) => `
          <div class="detail-row">
            <span class="k mono">${vout.scriptPubKey.address || vout.scriptPubKey.type || "(no address)"}</span>
            <span class="v">${formatCac(Math.round(vout.value * Number(COIN)))} CAC</span>
          </div>`).join("")}
      </div>
    `);
  } catch (e) {
    renderError(e.message);
  }
}

// --------------------------------------------------------------- address

async function renderAddress(address) {
  render('<div class="notice">Loading...</div>');
  try {
    const a = await api(`/api/address/${address}`);
    render(`
      <div class="card">
        <h2 style="margin-top:0">Address</h2>
        <div class="detail-row"><span class="k">Address</span><span class="v mono">${a.address}</span></div>
        <div class="detail-row"><span class="k">Balance</span><span class="v">${formatCac(a.balance_satoshis)} CAC</span></div>
        <div class="detail-row"><span class="k">UTXOs</span><span class="v">${a.utxo_count}</span></div>
      </div>
      <div class="card">
        <p class="notice">${a.note}</p>
      </div>
      <div class="card">
        <h3 style="margin-top:0">Unspent outputs</h3>
        <table>
          <thead><tr><th>Txid</th><th>Height</th><th>Value</th></tr></thead>
          <tbody>
            ${a.utxos.map((u) => `
              <tr>
                <td class="mono"><a href="#/tx/${u.txid}">${shorten(u.txid)}</a>:${u.vout}</td>
                <td>${u.height !== null ? `<a href="#/block/${u.height}">${u.height}</a>` : "-"}</td>
                <td>${formatCac(u.value_satoshis)} CAC ${u.is_coinbase_or_coinstake ? '<span class="badge coinbase">coinbase/stake</span>' : ""}</td>
              </tr>`).join("")}
          </tbody>
        </table>
      </div>
    `);
  } catch (e) {
    renderError(e.message);
  }
}

// ------------------------------------------------------------------ router

async function route() {
  const hash = location.hash.replace(/^#\/?/, "");
  const [kind, ...rest] = hash.split("/");
  const id = rest.join("/");
  if (kind !== "" && homeRefreshTimer) { clearInterval(homeRefreshTimer); homeRefreshTimer = null; }
  if (!kind) return renderHome();
  if (kind === "block") return renderBlock(id);
  if (kind === "tx") return renderTx(id);
  if (kind === "address") return renderAddress(id);
  if (kind === "richlist") return renderRichlist();
  renderError("Unknown page");
}

window.addEventListener("hashchange", route);
route();

// ------------------------------------------------------------------ search

async function doSearch() {
  const q = document.getElementById("search-input").value.trim();
  if (!q) return;
  try {
    const result = await api(`/api/search?q=${encodeURIComponent(q)}`);
    location.hash = `#/${result.type}/${result.id}`;
  } catch (e) {
    renderError(e.message);
  }
}
document.getElementById("search-btn").addEventListener("click", doSearch);
document.getElementById("search-input").addEventListener("keydown", (e) => {
  if (e.key === "Enter") doSearch();
});
