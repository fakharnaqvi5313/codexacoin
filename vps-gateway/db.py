"""SQLite storage for the gateway: user accounts, the staking pool's
per-user ledger, and the set of addresses the gateway node has imported
watch-only (see README.md for why watch-only import is this phase's
chosen backend instead of Electrum -- PARAMETERS.md section 13.1 has the
full reasoning)."""
import os
import sqlite3
import time
from contextlib import contextmanager

DB_PATH = os.environ.get("GATEWAY_DB_PATH", os.path.join(os.path.dirname(__file__), "gateway.db"))


def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at REAL NOT NULL,
                full_name TEXT,
                date_of_birth TEXT,
                id_type TEXT,
                id_number_encrypted TEXT
            )
            """
        )
        # Signup originally had no KYC fields (see PARAMETERS.md section
        # 13.6) -- ALTER TABLE ADD COLUMN for anyone whose users table
        # already exists from before these columns were added. SQLite has
        # no "ADD COLUMN IF NOT EXISTS", so check first.
        existing_cols = {row[1] for row in conn.execute("PRAGMA table_info(users)")}
        for col in ("full_name", "date_of_birth", "id_type", "id_number_encrypted"):
            if col not in existing_cols:
                conn.execute(f"ALTER TABLE users ADD COLUMN {col} TEXT")
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS watched_addresses (
                address TEXT PRIMARY KEY,
                imported_at REAL NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS stake_deposits (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id),
                deposit_address TEXT NOT NULL UNIQUE,
                funding_txid TEXT,
                funding_vout INTEGER,
                amount_satoshis INTEGER,
                status TEXT NOT NULL DEFAULT 'awaiting_funds',
                created_at REAL NOT NULL,
                withdrawn_at REAL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_deposits_user ON stake_deposits(user_id)")
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS stake_rewards (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                deposit_id INTEGER NOT NULL REFERENCES stake_deposits(id),
                coinstake_txid TEXT NOT NULL UNIQUE,
                gross_reward_satoshis INTEGER NOT NULL,
                pool_fee_satoshis INTEGER NOT NULL,
                net_reward_satoshis INTEGER NOT NULL,
                credited_at REAL NOT NULL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_rewards_deposit ON stake_rewards(deposit_id)")
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS push_subscriptions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id),
                endpoint TEXT NOT NULL UNIQUE,
                p256dh TEXT NOT NULL,
                auth TEXT NOT NULL,
                created_at REAL NOT NULL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_push_user ON push_subscriptions(user_id)")
        conn.commit()


@contextmanager
def db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def now():
    return time.time()
