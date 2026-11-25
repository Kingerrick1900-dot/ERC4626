#!/usr/bin/env python3
"""Air-gap PQ helper — hashes Dilithium/Kyber pubkeys for CrownPqRegistry. No private keys."""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path


def keccak_like_sha3(data: bytes) -> str:
    # eth_hash optional; use sha3-256 hex for offline; cast keccak preferred when foundry present
    try:
        import subprocess

        # write temp hex
        hx = data.hex()
        out = subprocess.check_output(["cast", "keccak", f"0x{hx}"], text=True).strip()
        return out
    except Exception:
        return "0x" + hashlib.sha3_256(data).hexdigest()


def main() -> None:
    p = argparse.ArgumentParser(description="KE-Sov PQ pubkey hash (air-gap)")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("register-dilithium", "register-kyber"):
        s = sub.add_parser(name)
        s.add_argument("--pubkey-file", required=True, type=Path)
        s.add_argument("--label", required=True)
    args = p.parse_args()
    raw = args.pubkey_file.read_bytes()
    if not raw:
        sys.exit("empty pubkey")
    h = keccak_like_sha3(raw)
    alg = "Dilithium3" if "dilithium" in args.cmd else "Kyber768"
    print(f"alg={alg}")
    print(f"label={args.label}")
    print(f"keyHash={h}")
    print("NEXT=CrownPqRegistry.register + activate on air-gap-approved HOT session")
    print("CUSTODY=air-gapped hardware · NFC-bound · King-only · no cloud")


if __name__ == "__main__":
    main()
