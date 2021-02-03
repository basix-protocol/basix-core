const BASIXPool = artifacts.require("BASIXPool");
const UFragments = artifacts.require("UFragments");
const UFragmentsPolicy = artifacts.require("UFragmentsPolicy");
const Orchestrator = artifacts.require("Orchestrator");
const BASIXOracle = artifacts.require("BASIXOracle");
const Deployer = artifacts.require("Deployer");
const IUniswapV2Router01 = artifacts.require("IUniswapV2Router01");


// 1. Deploy BASIXPool /Pool.sol
// 2. Deploy UFragments /UFragments.sol 
// 3. Deploy UFragmentsPolicy /UFragmentsPolicy.sol
// 4. Deploy Orchestrator /Orchestrator.sol
// 5. Create UNI Pair
// 6. Deploy BASIXOracle /Oracle.sol
// 7. Call setMonetaryPolicy() from UFragments
// 8. Call setMarketOracle() from UFragmentsPolicy
// 9. Call setOrchestrator() from UFragmentsPolicy
// 10. Call setRebaseTimingParameters(60, 30, 900) from UFragmentsPolicy // ONLY FOR TESTING POURPOSES
// 11. Call initialize() from BASIXPool
// 12. Call updateBeforeRebase() from BASIXOracle

async function deployTestnet(deployer, accounts) {
  const userAddress = accounts[0];

  await deployer.deploy(BASIXPool);
  await deployer.deploy(UFragments, "BASIX", "BASX",userAddress, BASIXPool.address);
  await deployer.deploy(UFragmentsPolicy, UFragments.address);
  await deployer.deploy(Orchestrator,
    UFragmentsPolicy.address,
    BASIXPool.address,
    UFragments.address,
    "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707",
    0
  );

  // Create UNI Pair
  await deployer.deploy(Deployer, UFragments.address, "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707");
  
  const uFragments = await UFragments.at(UFragments.address);
  await uFragments.approve("0x7a250d5630b4cf539739df2c5dacb4c659f2488d", "100000000000000000000");

  const usdc = await UFragments.at("0x680b96bd01ac9e50d1c80df8ba832f992e9e8707");
  await usdc.approve("0x7a250d5630b4cf539739df2c5dacb4c659f2488d", "100000000");

  const uniPar = await IUniswapV2Router01.at("0x7a250d5630b4cf539739df2c5dacb4c659f2488d");
  await uniPar.addLiquidity(
    UFragments.address,
    "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707",
    "100000000000000000000",
    "100000000",
    "100000000000000000000",
    "100000000",
    userAddress,
    Math.floor(Date.now() / 1000) + 600 // 10 minutes
  );

  await deployer.deploy(BASIXOracle,
    UFragments.address,
    "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707"
  );

  // UFragments
  await uFragments.setMonetaryPolicy(UFragmentsPolicy.address);

  // UFragmentsPolicy
  const uFragmentsPolicy = await UFragmentsPolicy.at(UFragmentsPolicy.address);
  await uFragmentsPolicy.setMarketOracle(BASIXOracle.address);
  await uFragmentsPolicy.setOrchestrator(Orchestrator.address);
  await uFragmentsPolicy.setRebaseTimingParameters(60, 30, 900);

  // BASIXPool
  const basixPool = await BASIXPool.at(BASIXPool.address);
  await basixPool.initialize(
    86400,
    "1000000000000000000",
    Math.floor(Date.now() / 1000),
    '0x680b96bd01ac9e50d1c80df8ba832f992e9e8707',
    UFragments.address,
    false
  );

  // BASIXOracle
  const basixOracle = await BASIXOracle.at(BASIXOracle.address);
  await basixOracle.updateBeforeRebase();
}

module.exports = async (deployer, network, accounts) => {
  await deployTestnet(deployer, accounts);
};
