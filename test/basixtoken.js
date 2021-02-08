const BasixToken = artifacts.require("BasixToken");

contract('BasixToken', (accounts) => {
  it('should put 10000 BASIX in the first account', async () => {
    const basixToken = await BasixToken.deployed();
    const balance = await basixToken.getBalance.call(accounts[0]);

    assert.equal(balance.valueOf(), 10000, "10000 wasn't in the first account");
  });
});
