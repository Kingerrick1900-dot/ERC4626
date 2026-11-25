# Kingdom Agent Runtime (KAR)

Sovereign execution plane for King Errick’s agents. **Not** a Cursor binary fork.

## Laws
- Default deny — `CrownAllowlist.check` before every broadcast
- `bordersSecure()` required when gate says so
- Raw private keys never enter the LLM context
- NFC cosign required (policy) for migrate / large payroll / cold release
- Hunt body blocked until King arms selector

## Commands
```bash
export PRIVATE_KEY=… BASE_RPC_URL=https://mainnet.base.org
python3 kar/runner.py status
python3 kar/runner.py check --target 0x128d… --sig 'firePayroll(uint256)'
python3 kar/runner.py attest --fire   # refresh epoch / borders
```

## Layout
- `policy.json` — RPCs, rails, selectors, key policy
- `runner.py` — policy-gated cast wrapper
- On-chain: `CrownAllowlist`, `CrownPayAdapter` (see deployments/FIRE-KAR-PLATFORM.md)
