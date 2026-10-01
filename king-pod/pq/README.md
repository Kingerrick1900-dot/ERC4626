# Post-quantum custody (Dilithium / Kyber)

**Law:** Air-gapped hardware · NFC-bound · King-only · **no cloud · no hot wallet · no LLM**.

This folder ships **CLI stubs** that hash public keys for `CrownPqRegistry`. Real Dilithium3 / Kyber768 signing runs on the King’s air-gap device; this repo never stores private keys.

```bash
# On air-gap machine (example):
python3 pq/pq_cli.py register-dilithium --pubkey-file /media/king/dilithium.pub --label king-root
python3 pq/pq_cli.py register-kyber --pubkey-file /media/king/kyber.pub --label king-kem
# Then HOT registers the printed keyHash on CrownPqRegistry
```
