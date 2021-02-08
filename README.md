# BASIX

Contracts for the BASIX protocol.

## Deploy

1. Deploy BasixPool /Pool.sol
2. Deploy BasixToken /BasixToken.sol 
3. Deploy BasixProtocol /BasixProtocol.sol
4. Deploy Orchestrator /Orchestrator.sol
5. Call BasixToken.addToWhitelist(UNI Pair address)
6. Add liquidity to UNI Pair
7. Deploy BasixOracle /Oracle.sol
8. Call BasixToken.setMonetaryPolicy()
9. Call BasixProtocol.setMarketOracle() 
10. Call BasixProtocol.setOrchestrator()
11. Call BasixProtocol.setRebaseTimingParameters(60, 30, 900)  // ONLY FOR TESTING POURPOSES
12. Call BasixPool.initialize() 
13. Call BasixOracle.updateBeforeRebase()
