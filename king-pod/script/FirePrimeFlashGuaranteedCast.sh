#!/usr/bin/env bash
# DEPRECATED — caused live \$4.5M debt / \$0 idle incident (tx 0x174cc502…).
echo "REFUSED: FirePrimeFlashGuaranteedCast is disabled."
echo "Flash round-trip fills order then borrows credit to repay flash — Landing stays at \$0."
echo "Paths that work: external 7683 solver fill, Morpho IdleTap when book has USDC, direct credit.supply()."
exit 1
