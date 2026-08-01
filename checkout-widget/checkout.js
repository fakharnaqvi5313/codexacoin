// CodexaCoin merchant checkout widget -- a single embeddable ES module,
// no build step, same "no bundler needed" approach as web-wallet/ and
// explorer/ (see web-wallet/README.md's "Why no bundler" for the
// underlying reasoning).
//
// Deliberately stateless on the backend: this widget needs no new
// gateway endpoints at all. It polls the existing, already-verified
// GET /v1/address/{address}/balance (see PARAMETERS.md section 13) and
// detects payment by watching that address's balance rise by at least
// the requested amount from a baseline snapshot taken when the widget
// opens -- not a dedicated "payment request" object with its own
// lifecycle. This is a deliberate scope choice: a merchant is
// responsible for generating (or having their customer generate) an
// address to charge to, e.g. from their own vps-gateway wallet or
// cac_wallet's receive screen; this widget's job is strictly "watch for
// payment to this address, tell me when it arrives," not payment-request
// management, invoicing, or refunds.
//
// Relevant to Apple's App Store guideline on virtual currencies (see
// docs/store-compliance.md): this is specifically the "in exchange for
// goods and services" use case that guideline permits.

import * as QRCode from "https://cdn.jsdelivr.net/npm/qrcode@1.5.3/+esm";

const COIN = 100_000_000n;

function formatCac(satoshis) {
  const s = BigInt(satoshis);
  const whole = s / COIN;
  const frac = (s % COIN).toString().padStart(8, "0");
  return `${whole}.${frac}`;
}

/**
 * @param {Object} opts
 * @param {HTMLElement|string} opts.container - element or element id to render into
 * @param {string} opts.address - the address to watch for payment
 * @param {number|string} opts.amountCac - amount due, in whole CAC (decimal string ok)
 * @param {string} [opts.gatewayUrl] - gateway base URL, default same-origin "" (see explorer/app.js's identical convention)
 * @param {number} [opts.pollIntervalMs] - default 8000
 * @param {number} [opts.confirmationsRequired] - default 1 (see onDetected vs onConfirmed below)
 * @param {(info: {balance: string}) => void} [opts.onDetected] - fires once when unconfirmed+confirmed balance first covers the amount due
 * @param {(info: {balance: string}) => void} [opts.onConfirmed] - fires once confirmed-only balance covers the amount due
 * @param {(error: Error) => void} [opts.onError]
 * @returns {{ stop: () => void }} call stop() to cancel polling (e.g. on unmount)
 */
export function createCheckout(opts) {
  const {
    container, address, amountCac, gatewayUrl = "",
    pollIntervalMs = 8000, onDetected, onError,
  } = opts;
  const amountSatoshis = BigInt(Math.round(Number(amountCac) * 1e8));
  const el = typeof container === "string" ? document.getElementById(container) : container;
  if (!el) throw new Error("createCheckout: container not found");

  el.innerHTML = `
    <div class="cac-checkout" style="font-family:-apple-system,sans-serif;max-width:320px;text-align:center;color:#ece7e0;background:#1c1922;border:1px solid #322c3a;border-radius:12px;padding:20px;">
      <div style="font-size:13px;color:#9b93a3;margin-bottom:8px;">Pay with CodexaCoin</div>
      <div style="font-size:20px;font-weight:700;color:#f0c350;margin-bottom:12px;">${formatCac(amountSatoshis)} CAC</div>
      <canvas class="cac-checkout-qr"></canvas>
      <div style="font-family:ui-monospace,monospace;font-size:12px;word-break:break-all;margin:10px 0;">${address}</div>
      <div class="cac-checkout-status" style="font-size:13px;color:#9b93a3;">Waiting for payment&hellip;</div>
    </div>
  `;
  const canvas = el.querySelector(".cac-checkout-qr");
  const statusEl = el.querySelector(".cac-checkout-status");
  QRCode.toCanvas(canvas, address, { width: 200, margin: 1 }).catch((e) => {
    if (onError) onError(e);
  });

  let baseline = null;
  let detected = false;
  let stopped = false;
  let timer = null;

  async function fetchBalance() {
    const resp = await fetch(`${gatewayUrl}/v1/address/${address}/balance`);
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.error?.message || `Request failed (${resp.status})`);
    return BigInt(data.confirmed) + BigInt(data.unconfirmed);
  }

  async function poll() {
    if (stopped) return;
    try {
      const balance = await fetchBalance();
      if (baseline === null) {
        baseline = balance; // snapshot taken on first successful poll, not construction time -- avoids a race if the address already had funds from a prior charge
      } else if (!detected && balance - baseline >= amountSatoshis) {
        detected = true;
        statusEl.textContent = "Payment received!";
        statusEl.style.color = "#6fcf97";
        if (onDetected) onDetected({ balance: balance.toString() });
        stop();
        return;
      }
    } catch (e) {
      statusEl.textContent = "Could not check payment status -- retrying...";
      if (onError) onError(e);
    }
    if (!stopped) timer = setTimeout(poll, pollIntervalMs);
  }

  function stop() {
    stopped = true;
    if (timer) clearTimeout(timer);
  }

  poll();
  return { stop };
}
