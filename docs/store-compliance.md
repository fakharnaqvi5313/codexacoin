# App Store / Google Play compliance — CodexaCoin mobile wallet

Phase 5 deliverable. Summarizes the specific policy constraints that
shaped the mobile app's architecture, and confirms the hard requirement
the whole design hinges on: **zero on-device mining, staking, or
background processing, on either platform.**

## The constraint that drives everything else

Apple App Store Review Guideline 3.1.5(b) ("Virtual Currencies") permits
apps to facilitate transmission of approved virtual currency in
compliant, lawful ways, but bars an app from mining cryptocurrency using
its own on-device mechanism — mining is only allowed if it happens off
device (e.g. via cloud-based mining), quoting the guideline's own phrase
for that exception: *"performed off device"*.

Google Play's Financial Services / Cryptocurrency policy is less
prescriptive in exact wording but enforces the same practical constraint
via its Device and Network Abuse policy (prohibiting apps that run
persistent background compute, drain battery, or mine cryptocurrency on
the user's hardware without clear, foreground-only consent) and its
general stance that mining apps are restricted from Google Play outright.

**CodexaCoin's design response, stated once here and enforced everywhere
else in this codebase**: the mobile apps are pure **light wallets**. They
generate/store keys, sign transactions, and display balances/history. They
never mine, never stake, and never run any continuous or
background-scheduled computation. All staking happens on the VPS staking
service (Phase 6) — see PARAMETERS.md's Phase 6 design (6A custodial pool,
6B non-custodial cold-staking). This is not a workaround to slip past
review; it's a straightforwardly compliant architecture, and it happens to
also be strictly better for users (no battery drain, no background
permissions, no continuous connectivity requirement, no missed rewards
from forgetting to keep the app open).

## What "zero on-device staking" actually means in the code

Concretely, and checkably:

- No `WorkManager` (Android) / `BGTaskScheduler` (iOS) registrations, no
  background isolates, no scheduled/periodic tasks of any kind in the
  Flutter project (`cac_wallet/`).
- No proof-of-work or proof-of-stake kernel-search logic exists anywhere
  in the Dart source. The staking screen (`lib/screens/staking_screen.dart`)
  is **read-only display + remote API calls** — every action it exposes
  (view status, deposit, withdraw, delegate, revoke) is an HTTP call to
  the gateway service specified in `docs/mobile-api.md`, never local
  computation. Search the codebase yourself:
  `grep -ri "mine\|kernel\|proof.of.work\|proof.of.stake" cac_wallet/lib/`
  should turn up nothing except this compliance boundary being described
  in comments/docs.
- Signing (the one thing that *does* happen on-device, necessarily — see
  below) is a single bounded cryptographic operation per user-initiated
  send, not a continuous process. It does not run when the app is
  backgrounded or closed.

## Key handling (Apple/Google security expectations, not just policy)

Both platforms increasingly expect — and reviewers do check for — proper
use of platform key storage rather than app-managed files:

- **iOS**: keys stored via `flutter_secure_storage`, which uses the
  Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (device-only,
  never iCloud Keychain synced — a wallet seed must never leave the
  device via any sync mechanism). Where the device supports it, the
  Secure Enclave backs the Keychain item.
- **Android**: same package, backed by the Android Keystore system
  (hardware-backed on devices that support StrongBox).
- Signing happens **entirely on-device**, in the Flutter/Dart process.
  Only the final signed transaction hex is ever sent over the network
  (to the gateway's `/v1/tx/broadcast`, see `docs/mobile-api.md`) — private
  keys and unsigned transaction data never leave the device.
- Biometric app-lock (`local_auth`) gates *app access*, not signing itself
  — a deliberate simplification for this phase; a future hardening pass
  could additionally require biometric confirmation per-transaction, not
  just per-session.

## Offline-first behavior and its UI-copy implication

Per the spec: keys, cached balances, cached history, and the receive-QR
must all work with no network at all. Network access is needed only to
*sync* balances/rewards and to *broadcast* a transaction. This has a
specific, deliberate UI-copy consequence enforced in this app: staking
reward copy says **"rewards accrue automatically — no need to keep the
app open or online"**, never "works without internet" — the app genuinely
needs a network sync to *show* an updated balance or to *send* anything;
what it doesn't need is to be open or running for rewards to accrue
server-side. Getting this distinction right matters for App Store/Play
review (overstating offline capability is the kind of claim reviewers and
users alike will find wrong the first time someone tries to check their
balance on a plane).

## Fiat value, BIP39, QR, testnet/mainnet switch

None of these have policy implications beyond the general "don't mislead
users" principle:

- Fiat value is an explicit **placeholder** (no live price feed wired up
  this phase — see `lib/widgets/fiat_placeholder.dart`), labeled as such in
  the UI rather than showing a fabricated number.
- BIP39 mnemonic (12-word) seed creation/restore, standard derivation path
  (`m/44'/<coin_type>'/0'/0/n` using CAC's placeholder BIP44 coin type —
  see PARAMETERS.md §2, still pending SLIP-44 registration).
- QR: generate for receive (`qr_flutter`), scan for send (`mobile_scanner`).
- Testnet/mainnet switch is a settings toggle that changes which chain
  parameters (address prefixes, gateway endpoint) the app uses — see
  `lib/config/network_config.dart`. Switching networks does **not** reuse
  the same keys across networks silently without the user understanding
  that; the app clearly labels which network is active at all times
  (a persistent banner when on testnet, matching the common convention of
  never letting testnet and mainnet look visually identical).

## Deliverables checklist (this phase)

- [x] Flutter project (`cac_wallet/`) targeting both iOS and Android from
      one codebase.
- [x] BIP39 seed creation/restore, key derivation.
- [x] Send/receive with QR, transaction history (via the Phase 4 gateway
      API), fiat-value placeholder, biometric app lock, testnet/mainnet
      switch.
- [x] Staking screen: status, accrued rewards, effective monthly rate;
      start/withdraw actions disabled with an explanatory message until
      the Phase 6 staking service exists — all via remote API calls only,
      nothing computed on-device. Delegate/revoke (6B, cold-staking) UI
      is not built this phase; the gateway client methods exist
      (`lib/services/gateway_api.dart`) but nothing calls them yet.
- [x] Unit tests for key derivation/signing.
- [ ] Integration test against a real testnet Electrum server + staking
      API — stubbed this phase (the gateway service itself doesn't exist
      yet; see `docs/mobile-api.md`'s own "specification, not
      implementation" caveat from Phase 4).
- [ ] Android APK/AAB actually built and installed on a device/emulator —
      see PARAMETERS.md §12 for exactly what was and wasn't verified
      locally this phase (no Android SDK on this development machine).
- [ ] iOS Xcode project actually built for the Simulator — blocked on this
      development machine by `xcode-select` pointing at Command Line
      Tools rather than full Xcode (fixable with
      `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`,
      which needs a password this session doesn't have and shouldn't
      request).
