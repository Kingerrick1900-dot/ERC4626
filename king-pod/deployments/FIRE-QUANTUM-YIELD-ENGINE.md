# FIRE — Quantum Yield Engine (software layer BUILT)

**Mode:** FIRE · Base  
**Doctrine:** Easy Trigger — armor not gate. Payroll before LLC. Docs are not the product — contracts are.

---

## LIVE (Base) — executed

| Module | Address |
|--|--|
| **CrownStarkSnarkBridge** | [`0x0E88d44F0a6dbD9FF1849DB18278388d74562B07`](https://basescan.org/address/0x0E88d44F0a6dbD9FF1849DB18278388d74562B07) |
| **CrownPqRegistry** | [`0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95`](https://basescan.org/address/0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95) |
| **CrownEasyTrigger** | [`0x512c8ee4521474c2a2E56C033072d56f1998cc6d`](https://basescan.org/address/0x512c8ee4521474c2a2E56C033072d56f1998cc6d) |
| **CrownQkdPilot** | [`0xC19c7fe9aC7D65476BBd91BD275443761FFe430F`](https://basescan.org/address/0xC19c7fe9aC7D65476BBd91BD275443761FFe430F) |
| **CrownAmericaCapacity** | [`0xa372d32ca9Ad06e76Ad5468767D9ae596387E4b3`](https://basescan.org/address/0xa372d32ca9Ad06e76Ad5468767D9ae596387E4b3) · **100T** · unlocked **0** |
| Curator tranche (wired) | `0x8531F4DB622b982541A6715164d5A9dde58205b0` |

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
