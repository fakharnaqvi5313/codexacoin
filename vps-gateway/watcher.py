#!/usr/bin/env python3
"""Runs one staking-pool watcher pass (deposit-funded detection + reward
attribution) plus one mobile-push incoming-payment check, and exits.
Meant to be invoked periodically -- see
provisioning/vps-gateway/gateway-watcher.timer for the systemd timer that
does this in production. Run standalone for local testing:

    python3 watcher.py
"""
import db
import mobile_notify
import staking

if __name__ == "__main__":
    db.init_db()
    staking.run_watcher_pass()
    mobile_notify.check_incoming_payments()
    print("watcher pass complete")
