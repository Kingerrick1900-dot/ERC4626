# Speed kit — Scribe notes

## Live machine
Legal Morpho vault fill works on Base. Debt clears to 0. 100% USDC to kingdom vault.

- Flash closer: `0x2192251a8FD4a31843fDE1222C43Ac0ad64ccD25`
- Desk: `0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF`
- Vault: `0xA1aFcb46a64C9173519180458C1cF302179c832a`

## What speeds shots
1. Desk-only flash rail (no Morpho pre-fund)
2. Harvest leftover Morpho supply into the next fire
3. Fire `eliteFlashClose` whenever desk has USDC

Same proven pattern. Bigger rails → bigger vault hits. No lectures.
