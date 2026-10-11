# LAW — King rotation: what EIP-7702 can and cannot do

**Gate:** `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` (`CrownGateV2`)  
**Live pending King:** `0x5E07D7167282F9ec912a05c3048D7D0F24A8b826` (new cold)  
**Landing** `0x5Adcea…2357` is **not** pending (superseded).

---

## Verdict

**The machine cannot complete the rotation by “wiring Landing as a signer” and firing an internal call without the pending wallet’s approval.**

`acceptKingship()` on the **deployed** gate is:

```solidity
function acceptKingship() external {
    if (msg.sender != pendingKing) revert NotKing();
    king = pendingKing;
    pendingKing = address(0);
}
```

There is **no** `setSigner`, **no** `acceptWithSignature`, **no** AA entrypoint, **no** EIP-7702 hook on this contract.  
Only an account whose address equals **`pendingKing()`** can accept — today that is the **new cold** `0x5E07…b826`.

---

## What EIP-7702 actually does here

| Claim | Reality on this gate |
|--|--|
| Machine wires Landing / cold as “recognized signer” | **False** — gate has no such registry |
| Machine triggers internal tx; wallet only approves once without exposure | Wallet **must** authorize a tx (or 7702 auth) as **`msg.sender == pendingKing`** |
| Private key never leaves wallet | **True** for MetaMask / Ledger / Cake — that is already the path |
| Skip Basescan / Remix / cast | **True** if MetaMask connects to verified Write Contract |

EIP-7702 can batch/sponsor gas for an EOA that has delegated code. It does **not** let HOT or the agent call `acceptKingship` and have it count as the new cold.

---

## Correct simple path (King is not a technician)

1. Open MetaMask with account **`0x5E07D7167282F9ec912a05c3048D7D0F24A8b826`**
2. Network **Base**
3. Open [Write Contract](https://basescan.org/address/0x76fa390951fA31185490378F46B6e9F05bA4bC3b#writeContract)
4. Connect MetaMask → **`acceptKingship`** → Confirm  
5. **`setOperator(0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1, true)`** → Confirm  

Key stays in MetaMask. Machine never holds it. Two confirms (or one if batched later).

---

## If the King wants Landing instead of new cold

HOT must call `initiateKingTransfer(0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357)` again, then **Landing** MetaMask does the same two writes. Agent can re-initiate on command.

---

## If the King wants a true one-sig AA design later

That requires a **new gate** (or upgrade path) with e.g. `acceptKingshipWithSig(v,r,s)` / ERC-4337 — then migrate Morpho position. **Not** available on live `0x76fa…` without redeploy.

```
LAW=NO_FAKE_7702_ROTATION
PENDING=0x5E07D7167282F9ec912a05c3048D7D0F24A8b826
ACCEPT=msg.sender_must_be_pendingKing
SIMPLE_PATH=MetaMask_WriteContract
```
