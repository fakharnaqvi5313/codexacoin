"""One-time keypair generation for a third Stellar account used only as
the counterparty for the project-seeded chart-history trades (see
seed_chart_history.py). Appends to the existing secrets.local.txt in the
same format generate_keys.py uses -- chmod 600, gitignored, never printed
to stdout beyond the public key.
"""
import os
from stellar_sdk import Keypair

trader = Keypair.random()

secrets_path = os.path.join(os.path.dirname(__file__), "secrets.local.txt")
with open(secrets_path, "a") as f:
    f.write("\nCAC trader account (counterparty for project-seeded chart-history trades only)\n")
    f.write(f"Public:  {trader.public_key}\n")
    f.write(f"Secret:  {trader.secret}\n")
os.chmod(secrets_path, 0o600)

print("Secret seed appended to secrets.local.txt (chmod 600, gitignored).")
print()
print(f"Trader public key: {trader.public_key}")
print()
print("Doesn't exist on the Stellar network yet -- needs a small amount of")
print("real XLM sent to it before seed_chart_history.py can run (needs ~1.5 XLM")
print("just to exist with a trustline, plus the XLM actually used in the trades).")
