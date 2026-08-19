# RSS $1200 raise pipe

Vault list + PA flow + draw. Same Morpho bootstrap every new market uses.

```
KING_OK=1 forge script script/ArmYrss1200.s.sol:ArmYrss1200 --rpc-url $BASE_RPC_URL --broadcast --slow
# when idle >= 700k:
KING_OK=1 forge script script/BorrowIdleToLanding.s.sol:BorrowIdleToLanding --rpc-url $BASE_RPC_URL --broadcast --slow
```

Merkl supply campaign: `merkl-rss-1200-supply.json`
