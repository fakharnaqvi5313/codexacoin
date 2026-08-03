"""One-time keypair generation for the CAC Stellar issuer + distributor
accounts. Secret seeds are written ONLY to secrets.local.txt (chmod 600,
gitignored, never printed to stdout/logs) -- move them to a password
manager and delete that file once you've done so. Only public keys are
printed, since those are safe to share/commit.
"""
import os
from stellar_sdk import Keypair

issuer = Keypair.random()
distributor = Keypair.random()

secrets_path = os.path.join(os.path.dirname(__file__), "secrets.local.txt")
with open(secrets_path, "w") as f:
    f.write("CAC issuer account (creates/backs the asset -- keep this key the most secure)\n")
    f.write(f"Public:  {issuer.public_key}\n")
    f.write(f"Secret:  {issuer.secret}\n\n")
    f.write("CAC distributor account (holds/distributes circulating supply for trading)\n")
    f.write(f"Public:  {distributor.public_key}\n")
    f.write(f"Secret:  {distributor.secret}\n")
os.chmod(secrets_path, 0o600)

print("Secret seeds written to secrets.local.txt (chmod 600, gitignored).")
print("Move them to a password manager, then delete that file.\n")
print("Public keys (safe to share):")
print(f"  Issuer:       {issuer.public_key}")
print(f"  Distributor:  {distributor.public_key}")
print()
print("Neither account exists on the Stellar network yet -- each needs a small")
print("amount of real XLM sent to it to actually be created (minimum ~1 XLM each).")
