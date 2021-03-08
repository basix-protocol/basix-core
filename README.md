# BASIX

Contracts for the BASIX protocol.

## Deploy Core

1. Deploy BasixPool /Pool.sol
2. Deploy BasixToken /BasixToken.sol 
3. Deploy BasixProtocol /BasixProtocol.sol
4. Deploy Orchestrator /Orchestrator.sol
5. Call BasixToken.addToWhitelist(UNIPair.address)
6. Add liquidity to UNI Pair
7. Deploy BasixOracle /Oracle.sol
8. Call BasixToken.setMonetaryPolicy()
9. Call BasixProtocol.setMarketOracle() 
10. Call BasixProtocol.setOrchestrator()
11. Call BasixPool.initialize() 
13. Call BasixToken.addToWhitelist(BasixPool.address);

_Wait 24h_

14. Call BasixOracle.updateBeforeRebase()

## Deploy NFT

1. Deploy BasixNFT /BasixNFT.sol
2. Deploy BasixNFTSale /BasixNFTSale.sol 
3. Transfer BasixNFT ownsership to BasixNFTSale