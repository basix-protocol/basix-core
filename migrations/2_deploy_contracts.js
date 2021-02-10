const BasixPool = artifacts.require("BasixPool");
const BasixToken = artifacts.require("BasixToken");
const BasixProtocol = artifacts.require("BasixProtocol");
const Orchestrator = artifacts.require("Orchestrator");
const BasixOracle = artifacts.require("BasixOracle");
const Deployer = artifacts.require("Deployer");
const IUniswapV2Router01 = artifacts.require("IUniswapV2Router01");
const BasixSale = artifacts.require("BasixSale");

async function deployTestnet(deployer, accounts) {
  const userAddress = accounts[0];

  await deployer.deploy(BasixPool);
  await deployer.deploy(BasixToken, "BASIX", "BASX", userAddress, BasixPool.address);
  await deployer.deploy(BasixProtocol, BasixToken.address);
  await deployer.deploy(Orchestrator,
    BasixProtocol.address,
    BasixPool.address,
    BasixToken.address,
    "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707",
    0
  );
  await deployer.deploy(BasixPrivateSale, BasixToken.address, userAddress);
  await deployer.deploy(BasixSale, BasixToken.address);

  // Create UNI Pair
  await deployer.deploy(Deployer, BasixToken.address, "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707");
  
  const basixToken = await BasixToken.at(BasixToken.address);
  await basixToken.approve("0x7a250d5630b4cf539739df2c5dacb4c659f2488d", "100000000000000000000");

  const usdc = await BasixToken.at("0x680b96bd01ac9e50d1c80df8ba832f992e9e8707");
  await usdc.approve("0x7a250d5630b4cf539739df2c5dacb4c659f2488d", "100000000");

  const uniPar = await IUniswapV2Router01.at("0x7a250d5630b4cf539739df2c5dacb4c659f2488d");
  await uniPar.addLiquidity(
    BasixToken.address,
    "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707",
    "100000000000000000000",
    "100000000",
    "100000000000000000000",
    "100000000",
    userAddress,
    Math.floor(Date.now() / 1000) + 600 // 10 minutes
  );

  await deployer.deploy(BasixOracle,
    BasixToken.address,
    "0x680b96bd01ac9e50d1c80df8ba832f992e9e8707"
  );

  // BasixToken
  await basixToken.setMonetaryPolicy(BasixProtocol.address);

  // BasixProtocol
  const basixProtocol = await BasixProtocol.at(BasixProtocol.address);
  await basixProtocol.setMarketOracle(BasixOracle.address);
  await basixProtocol.setOrchestrator(Orchestrator.address);
  // await basixProtocol.setRebaseTimingParameters(60, 30, 900);

  // BasixPool
  const basixPool = await BasixPool.at(BasixPool.address);
  await basixPool.initialize(
    259200, // 72 h
    "200000000000000000000000",
    Math.floor(Date.now() / 1000), // Now
    '0x680b96bd01ac9e50d1c80df8ba832f992e9e8707',
    BasixToken.address,
    true
  );

  // BasixOracle
  const basixOracle = await BasixOracle.at(BasixOracle.address);
  // await basixOracle.updateBeforeRebase();
}

module.exports = async (deployer, network, accounts) => {
  await deployTestnet(deployer, accounts);
};
