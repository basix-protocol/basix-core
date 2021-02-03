# BASIX

Contracts for the BASIX protocol.

## Deploy

1. Deploy BASIXPool /Pool.sol
2. Deploy UFragments /UFragments.sol 
3. Deploy UFragmentsPolicy /UFragmentsPolicy.sol
4. Deploy Orchestrator /Orchestrator.sol
5. Call UFragments.addToWhitelist(UNI Pair address)
6. Add liquidity to UNI Pair
7. Deploy BASIXOracle /Oracle.sol
8. Call UFragments.setMonetaryPolicy()
9. Call UFragmentsPolicy.setMarketOracle() 
10. Call UFragmentsPolicy.setOrchestrator()
11. Call UFragmentsPolicy.setRebaseTimingParameters(60, 30, 900)  // ONLY FOR TESTING POURPOSES
12. Call BASIXPool.initialize() 
13. Call BASIXOracle.updateBeforeRebase()
