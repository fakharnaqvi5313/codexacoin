"""Places a resting sell offer on Stellar's DEX from the distributor
account: CAC for sale against XLM, establishing the reference price.

Confirmed on-chain 2026-08-03: distributor holds 10,000,000 CAC
(GA3VI7RXW347PRMOYIPKGHODVYJAURJCPYJ2MPCM77ZCHST2BBQOHB3W). This offers
a portion of that at the agreed initial rate of 1 XLM = 14 CAC.

Reads secrets.local.txt for the distributor's secret seed.
"""
from stellar_sdk import Server, Keypair, TransactionBuilder, Asset, Network, Price

HORIZON_URL = "https://horizon.stellar.org"  # mainnet
ISSUER_PUBLIC = "GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y"
ASSET_CODE = "CAC"

# Amount of CAC to offer for sale, and the price (in XLM per CAC).
# 1 XLM = 14 CAC  =>  1 CAC = 1/14 XLM.
SELL_AMOUNT = 500000
PRICE = Price(n=1, d=14)


def load_distributor_secret():
    with open("secrets.local.txt") as f:
        lines = f.read()
    section = None
    for line in lines.splitlines():
        if line.startswith("CAC distributor"):
            section = "distributor"
        elif line.startswith("CAC issuer"):
            section = "issuer"
        elif line.startswith("Secret:") and section == "distributor":
            return line.split("Secret:")[1].strip()
    raise RuntimeError("Could not find distributor secret in secrets.local.txt")


def main():
    distributor_kp = Keypair.from_secret(load_distributor_secret())
    cac_asset = Asset(ASSET_CODE, ISSUER_PUBLIC)
    xlm_asset = Asset.native()

    server = Server(HORIZON_URL)
    account = server.load_account(distributor_kp.public_key)

    tx = (
        TransactionBuilder(account, Network.PUBLIC_NETWORK_PASSPHRASE, base_fee=100)
        .append_manage_sell_offer_op(
            selling=cac_asset,
            buying=xlm_asset,
            amount=str(SELL_AMOUNT),
            price=PRICE,
        )
        .set_timeout(60)
        .build()
    )
    tx.sign(distributor_kp)
    resp = server.submit_transaction(tx)
    print(f"Offer placed: selling {SELL_AMOUNT} {ASSET_CODE} at {PRICE.n}/{PRICE.d} XLM per {ASSET_CODE}")
    print(f"Transaction hash: {resp['hash']}")


if __name__ == "__main__":
    main()
