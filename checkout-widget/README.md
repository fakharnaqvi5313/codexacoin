# checkout-widget

A merchant "Pay with CodexaCoin" widget — a single embeddable ES module
(`checkout.js`), no build step, same no-bundler approach as `web-wallet/`
and `explorer/`.

Relevant to Apple's App Store guideline on virtual currencies (see
`docs/store-compliance.md`): this is specifically the "in exchange for
goods and services" use case that guideline permits.

## Design

Deliberately stateless on the backend — no new gateway endpoints needed.
It polls the existing `GET /v1/address/{address}/balance` (already
verified extensively — see `PARAMETERS.md` section 13) and detects
payment by watching the address's balance rise by at least the requested
amount from a baseline snapshot taken when the widget opens. The
merchant is responsible for generating the address to charge to (e.g.
from their own `vps-gateway` wallet, or a customer-facing `cac_wallet`
receive address); this widget's job is strictly "watch for payment,
tell me when it arrives" — not payment-request management, invoicing,
or refunds.

## Usage

```html
<div id="checkout"></div>
<script type="module">
  import { createCheckout } from "./checkout.js";
  createCheckout({
    container: "checkout",
    address: "C...",       // address to charge
    amountCac: "10.5",     // amount due
    gatewayUrl: "https://gateway.codexacoin.example", // default: same-origin
    onDetected: ({ balance }) => { /* mark the order paid */ },
    onError: (err) => { /* show a retry message */ },
  });
</script>
```

## Verification (Phase 7)

Tested end-to-end on regtest (chosen for immediately-spendable funds --
mainnet's premine is still inside its 500-block maturity window as of
this writing, so nothing there is spendable yet to test a real payment
with): rendered the QR + amount + address correctly, then a real
`sendtoaddress` payment to the watched address was correctly detected --
`onDetected` fired with the exact balance in satoshis matching the sent
amount, and the status UI updated to "Payment received!".
