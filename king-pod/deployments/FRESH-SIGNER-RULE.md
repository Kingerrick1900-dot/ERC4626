# Fresh throwaway signer — clean rule

**King generates the wallet.** MetaMask (or Cake) on King’s own phone/laptop. Seed written by hand. Offline if possible.

**Engineer gets only the public address** — wired into scripts as the ATTACK signer / Morpho authorizer / share receiver path as needed. **Never the private key. Never the seed. Not in chat.**

Same rule as multi-sig intent: engineer prepares; King alone controls the key that can fire.

**How the mission still runs**
1. King creates wallet → sends **address only** to scribe.
2. Scribe updates `HOT`/signer constants, PREP auth targets, atomic attack→landing wiring.
3. King tops gas + moves RSS to that address himself.
4. King runs/broadcasts the final `$9M` tx **locally** (his machine, his key) — or signs what the scribe prepared without pasting the key into Cursor.
5. After success: USDC on cold landing; retire throwaway if desired.

**Not clean:** engineer generates the key, or key pasted into this thread.
