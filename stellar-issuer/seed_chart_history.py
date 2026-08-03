"""Seeds a small round-trip of real trades against the CAC/XLM order book
so third-party DEX chart viewers (stellar.expert etc.) have something to
show besides an empty chart.

Be clear-eyed about what this is: both sides of these trades are accounts
controlled by the project (distributor + trader). This is a wash trade,
not organic demand. It's being done anyway, with the express instruction
to disclose it plainly wherever the resulting chart/history is referenced
-- see website/legal/proof-of-reserve.html. Don't run this and then
describe the resulting chart as reflecting real market activity.

Sequence (4 real transactions):
  1. Trader creates a trustline to the CAC asset.
  2. Trader buys ~TRADE_CAC_AMOUNT CAC for TRADE_XLM_AMOUNT XLM, crossing
     the distributor's existing resting sell offer -> one "buy" trade.
  3. Distributor places a new resting buy offer for the same amount.
  4. Trader sells that CAC back, crossing the distributor's new buy
     offer -> one "sell" trade. Net effect: trader ends near where it
     started (minus ~4 network fees, a few thousandths of an XLM);
     the distributor's total CAC/XLM position is essentially unchanged.

Reads secrets.local.txt for the distributor's and trader's secret seeds.
"""
from stellar_sdk import Server, Keypair, TransactionBuilder, Asset, Network, Price

HORIZON_URL = "https://horizon.stellar.org"  # mainnet
ISSUER_PUBLIC = "GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y"
ASSET_CODE = "CAC"

TRADE_PRICE = Price(n=1, d=14)  # 1 XLM = 14 CAC, matches the resting offer
TRADE_XLM_AMOUNT = 2
TRADE_CAC_AMOUNT = TRADE_XLM_AMOUNT * 14  # 28


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
    tx = (
        TransactionBuilder(source_account, Network.PUBLIC_NETWORK_PASSPHRASE, base_fee=100)
        .set_timeout(60)
    )
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

    # 1. Trader establishes a trustline to CAC.
    trader_account = server.load_account(trader_kp.public_key)
    submit(
        server, trader_account, trader_kp,
        lambda tx: tx.append_change_trust_op(asset=cac_asset),
        "Trustline created (trader -> CAC)",
    )

    # 2. Trader buys CAC with XLM, crossing the distributor's resting sell offer.
    trader_account = server.load_account(trader_kp.public_key)
    submit(
        server, trader_account, trader_kp,
        lambda tx: tx.append_manage_buy_offer_op(
            selling=xlm_asset, buying=cac_asset,
            amount=str(TRADE_CAC_AMOUNT), price=TRADE_PRICE,
        ),
        f"Trade 1 (buy): trader bought ~{TRADE_CAC_AMOUNT} CAC for ~{TRADE_XLM_AMOUNT} XLM",
    )

    # 3. Distributor places a fresh resting buy offer for the same amount.
    distributor_account = server.load_account(distributor_kp.public_key)
    submit(
        server, distributor_account, distributor_kp,
        lambda tx: tx.append_manage_buy_offer_op(
            selling=xlm_asset, buying=cac_asset,
            amount=str(TRADE_CAC_AMOUNT), price=TRADE_PRICE,
        ),
        "Distributor placed a resting buy offer",
    )

    # 4. Trader sells the CAC back, crossing the distributor's new buy offer.
    trader_account = server.load_account(trader_kp.public_key)
    submit(
        server, trader_account, trader_kp,
        lambda tx: tx.append_manage_sell_offer_op(
            selling=cac_asset, buying=xlm_asset,
            amount=str(TRADE_CAC_AMOUNT), price=TRADE_PRICE,
        ),
        f"Trade 2 (sell): trader sold ~{TRADE_CAC_AMOUNT} CAC for ~{TRADE_XLM_AMOUNT} XLM",
    )

    print()
    print("Done. Verify at:")
    print(f"  https://horizon.stellar.org/accounts/{distributor_kp.public_key}/trades")
    print(f"  https://stellar.expert/explorer/public/asset/CAC-{ISSUER_PUBLIC}")


if __name__ == "__main__":
    main()
