#!/usr/bin/env python3
"""NFC cosign — Easy Trigger second factor. Card never exports seed."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def cast_sig(sig: str) -> str:
    return subprocess.check_output(["cast", "sig", sig], text=True).strip()


def receipt_for(tx_hash_or_intent: str, card_id: str) -> str:
    """Simulate NFC tap → receipt hash. Hardware returns ECDSA; we bind intent+card."""
    material = f"NFC|{card_id}|{tx_hash_or_intent}|{int(time.time())}".encode()
    # Prefer cast keccak
    try:
        return subprocess.check_output(
            ["cast", "keccak", material.hex() if False else f"NFC-{card_id}-{tx_hash_or_intent}"],
            text=True,
        ).strip()
    except Exception:
        return "0x" + hashlib.sha3_256(material).hexdigest()


def require_nfc(policy: dict, sig: str) -> bool:
    req = policy.get("keyPolicy", {}).get("nfcCosignRequiredFor", [])
    return sig in req


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--intent", required=True, help="tx hash or easyDeploy intent")
    ap.add_argument("--card-id", default=os.environ.get("NFC_CARD_ID", "KING-CARD-1"))
    ap.add_argument("--sig", default="", help="function sig if checking policy")
    args = ap.parse_args()
    policy = json.loads((ROOT / "policy.json").read_text())
    if args.sig and not require_nfc(policy, args.sig):
        print("nfc_not_required_for", args.sig)
        return
    # Hardware stub: until SE card lands, King env NFC_COSIGN_SECRET stands in
    secret = os.environ.get("NFC_COSIGN_SECRET", "")
    if not secret and os.environ.get("NFC_HARDWARE") != "1":
        print("STUB: set NFC_HARDWARE=1 + card tap path, or NFC_COSIGN_SECRET for King standby", file=sys.stderr)
    r = receipt_for(args.intent, args.card_id + secret[:8])
    print(r)


if __name__ == "__main__":
    main()
