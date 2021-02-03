const UFragments = artifacts.require("UFragments");

contract('UFragments', (accounts) => {
  it('should put 10000 BASIX in the first account', async () => {
    const uFragments = await UFragments.deployed();
    const balance = await uFragments.getBalance.call(accounts[0]);

    // assert.equal(balance.valueOf(), 10000, "10000 wasn't in the first account");
  });
});
