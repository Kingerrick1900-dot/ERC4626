# FIRE — Quantum Yield Engine (software layer BUILT)

**Mode:** FIRE · Base  
**Doctrine:** Easy Trigger — armor not gate. Payroll before LLC. Docs are not the product — contracts are.

---

## Built (this fire)

| Module | Role |
|--|--|
| `CrownStarkSnarkBridge` | STARK digest → ZkAttest SNARK/epoch bind |
| `CrownPqRegistry` | Dilithium / Kyber **pubkey hashes** only (air-gap CLI in `pq/`) |
| `CrownEasyTrigger` | One-tap deploy path · NFC receipt · KAR + borders |
| `CrownQkdPilot` | China corridor packets · T0/+30d/+90d · attest bump |
| `CrownAmericaCapacity` | **100T** ceiling registry (unlock ≠ mint) |
| Ported | ZkAttest armor · zk circuits/gates · China NFC rails · KAR · Curator 200M |
| Ops | `kar/nfc_cosign.py` · `yield_ignition_scoreboard.sh` · `kar/runner.py scoreboard` |

## Commands

```bash
forge test --match-contract QuantumYieldEngineTest -vv
forge test --match-contract CuratorTrancheTest -vv

HOT_KEY=… forge script script/FireQuantumYieldEngine.s.sol:FireQuantumYieldEngine \
  --rpc-url $BASE_RPC_URL --broadcast

bash script/yield_ignition_scoreboard.sh
python3 kar/runner.py scoreboard
python3 kar/runner.py nfc --intent easyDeploy-1
```

## Still physics-gated

- **$200M curator deposit** needs real USDC fill (Ricardian path). Chassis already live.  
- **100T mint** needs `unlockTranche` + eUSD minter GO — capacity only until then.  
- **QKD** needs T0 fill then partner packets — contract is the log/attest rail.
