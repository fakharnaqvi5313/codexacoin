"""Completes the second half of the chart-history round trip started by
seed_chart_history.py: trade 1 (trader buying ~28 CAC for ~2 XLM) already
executed and is live on Horizon. This does trade 2 -- the distributor
places a fresh resting buy offer, then the trader sells its 28 CAC back
into it -- so the round trip (one buy + one sell) is complete.

Only run this if trade 1 already happened and trade 2 hasn't -- check
https://horizon.stellar.org/accounts/<distributor>/trades first.

Reads secrets.local.txt for the distributor's and trader's secret seeds.
"""
from stellar_sdk import Server, Keypair, TransactionBuilder, Asset, Network, Price

HORIZON_URL = "https://horizon.stellar.org"  # mainnet
ISSUER_PUBLIC = "GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y"
ASSET_CODE = "CAC"

# The distributor already has a resting SELL offer at 1/14 (1 XLM = 14 CAC).
# A buy offer at that same price is rejected by Stellar as MANAGE_BUY_OFFER_
# CROSS_SELF -- an account can't cross its own resting offer. Bidding at a
# slightly lower price (1/15) avoids the self-cross while still landing well
# within where the trader is willing to sell.
BUY_PRICE = Price(n=1, d=15)  # ~1 XLM = 15 CAC (distributor's bid)
TRADE_CAC_AMOUNT = 28


def load_secret(account_label):
    with open("secrets.local.txt") as f:
        lines = f.read()
    section = None
    for line in lines.splitlines():
        if line.startswith("CAC "):
            section = line
        elif line.startswith("Secret:") and section and section.startswith(account_label):
            return line.split("Secret:")[1].strip()
    raise RuntimeError(f"Could not find secret for '{account_label}' in secrets.local.txt")


def submit(server, source_account, kp, op_builder_fn, label):
    tx = TransactionBuilder(source_account, Network.PUBLIC_NETWORK_PASSPHRASE, base_fee=100).set_timeout(60)
    op_builder_fn(tx)
    tx = tx.build()
    tx.sign(kp)
    resp = server.submit_transaction(tx)
    print(f"{label}: tx {resp['hash']}")
    return resp


def main():
    distributor_kp = Keypair.from_secret(load_secret("CAC distributor"))
    trader_kp = Keypair.from_secret(load_secret("CAC trader"))
    cac_asset = Asset(ASSET_CODE, ISSUER_PUBLIC)
    xlm_asset = Asset.native()

    server = Server(HORIZON_URL)

    distributor_account = server.load_account(distributor_kp.public_key)
    submit(
        server, distributor_account, distributor_kp,
        lambda tx: tx.append_manage_buy_offer_op(
            selling=xlm_asset, buying=cac_asset,
            amount=str(TRADE_CAC_AMOUNT), price=BUY_PRICE,
        ),
        "Distributor placed a resting buy offer",
    )

    trader_account = server.load_account(trader_kp.public_key)
    submit(
        server, trader_account, trader_kp,
        lambda tx: tx.append_manage_sell_offer_op(
            selling=cac_asset, buying=xlm_asset,
            amount=str(TRADE_CAC_AMOUNT), price=BUY_PRICE,
        ),
        f"Trade 2 (sell): trader sold ~{TRADE_CAC_AMOUNT} CAC for ~1.87 XLM",
    )

    print()
    print("Done. Verify at:")
    print(f"  https://horizon.stellar.org/accounts/{distributor_kp.public_key}/trades")


if __name__ == "__main__":
    main()
