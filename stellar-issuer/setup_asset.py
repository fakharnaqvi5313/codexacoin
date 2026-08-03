"""Issues the CAC asset on Stellar and funds the distributor with the
agreed reserve-backed amount. Do NOT run this until:
  1. Both the issuer and distributor accounts (see README.md for their
     public keys) have been funded with real XLM and exist on the
     network.
  2. You've decided exactly how much CAC is being locked in the
     `stellar-reserve` wallet on the real CAC chain, and set
     ISSUE_AMOUNT below to match it exactly. This script does not (and
     cannot) touch the real CAC chain -- keeping the two loosely coupled
     is deliberate, so a bug here can never move real CAC.

Reads secrets.local.txt for both secret seeds -- see generate_keys.py.
"""
import sys
from stellar_sdk import Server, Keypair, TransactionBuilder, Asset, Network

HORIZON_URL = "https://horizon.stellar.org"  # mainnet
ASSET_CODE = "CAC"

# Set to exactly the amount of real CAC locked in the stellar-reserve
# wallet. Confirmed on-chain 2026-08-03: 10,000,000 CAC in a single UTXO
# at height 1004, address CPC7aKaDBkxFVTBugZGojSm8kwWeQ5qyfS.
ISSUE_AMOUNT = 10000000


def load_secrets():
    with open("secrets.local.txt") as f:
        lines = f.read()
    # Simple parse matching generate_keys.py's exact output format.
    issuer_secret = None
    distributor_secret = None
    section = None
    for line in lines.splitlines():
        if line.startswith("CAC issuer"):
            section = "issuer"
        elif line.startswith("CAC distributor"):
            section = "distributor"
        elif line.startswith("Secret:"):
            secret = line.split("Secret:")[1].strip()
            if section == "issuer":
                issuer_secret = secret
            elif section == "distributor":
                distributor_secret = secret
    if not issuer_secret or not distributor_secret:
        raise RuntimeError("Could not parse both secret seeds from secrets.local.txt")
    return issuer_secret, distributor_secret


def main():
    if ISSUE_AMOUNT is None:
        sys.exit(
            "ISSUE_AMOUNT is not set. Decide exactly how much CAC is locked in "
            "the stellar-reserve wallet first, then set ISSUE_AMOUNT to match "
            "before running this."
        )

    issuer_secret, distributor_secret = load_secrets()
    issuer_kp = Keypair.from_secret(issuer_secret)
    distributor_kp = Keypair.from_secret(distributor_secret)
    cac_asset = Asset(ASSET_CODE, issuer_kp.public_key)

    server = Server(HORIZON_URL)

    # 1. Distributor establishes a trustline to the CAC asset.
    distributor_account = server.load_account(distributor_kp.public_key)
    trust_tx = (
        TransactionBuilder(distributor_account, Network.PUBLIC_NETWORK_PASSPHRASE, base_fee=100)
        .append_change_trust_op(asset=cac_asset)
        .set_timeout(60)
        .build()
    )
    trust_tx.sign(distributor_kp)
    server.submit_transaction(trust_tx)
    print(f"Trustline created: distributor -> {ASSET_CODE}:{issuer_kp.public_key}")

    # 2. Issuer sends the agreed reserve-backed amount to the distributor.
    issuer_account = server.load_account(issuer_kp.public_key)
    issue_tx = (
        TransactionBuilder(issuer_account, Network.PUBLIC_NETWORK_PASSPHRASE, base_fee=100)
        .append_payment_op(destination=distributor_kp.public_key, asset=cac_asset, amount=str(ISSUE_AMOUNT))
        .set_timeout(60)
        .build()
    )
    issue_tx.sign(issuer_kp)
    server.submit_transaction(issue_tx)
    print(f"Issued {ISSUE_AMOUNT} {ASSET_CODE} to distributor.")
    print()
    print("Next: lock the issuer's ability to mint more by setting its master")
    print("key weight to 0 (or moving to multisig), then seed an AMM pool or")
    print("place DEX sell orders from the distributor account.")


if __name__ == "__main__":
    main()
