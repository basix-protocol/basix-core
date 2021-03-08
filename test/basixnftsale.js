const { expectRevert, expectEvent, BN } = require('@openzeppelin/test-helpers');
const truffleAssert = require('truffle-assertions');
const { expect } = require('chai');

const BasixToken = artifacts.require("BasixToken");
const BasixNFT = artifacts.require("BasixNFT");
const BasixNFTSale = artifacts.require("BasixNFTSale");

contract('BasixNFTSale', function (accounts) {
  
  beforeEach(async function () {
    this.basixToken = await BasixToken.new({ from: accounts[0] });
    this.basixNFT = await BasixNFT.new('Basix NFT', 'BNFT', 'https://basix.com/nft/', { from: accounts[0] });

    this.basixNFTSale = await BasixNFTSale.new(
      this.basixToken.address,
      this.basixNFT.address,
      { from: accounts[0] }
    );

    await this.basixNFT.transferOwnership(
      this.basixNFTSale.address,
      { from: accounts[0] }
    );

    const basixAmount = '10000000000000000000'; // 10 * (10 ** 18)
    
    this.basixToken.transfer(
      accounts[1],
      basixAmount,
      { from: accounts[0] }
    );

    this.basixToken.transfer(
      accounts[2],
      basixAmount,
      { from: accounts[0] }
    );

    await this.basixToken.approve(
      this.basixNFTSale.address,
      basixAmount,
      { from: accounts[1] }
    );

    await this.basixToken.approve(
      this.basixNFTSale.address,
      basixAmount,
      { from: accounts[2] }
    );
  }); 

  describe('basixToken', function () {

    it('has correct address value', async function() {
      assert.equal(
        await this.basixNFTSale.basixERC20.call().valueOf(),
        this.basixToken.address,
        'Instance has not correct basixToken value'
      );
    });

  });

  describe('basixNFT', function () {

    it('has correct address value', async function() {
      assert.equal(
        await this.basixNFTSale.basixERC721.call().valueOf(),
        this.basixNFT.address,
        'Instance has not correct basixNFT value'
      );
    });

  });

  describe('feesReceiver', function () {

    it('has correctly address value', async function() {
      assert.equal(
        await this.basixNFTSale.feesReceiver.call().valueOf(),
        accounts[0],
        'Not correct address value'
      );
    });

    it('changes correctly address value', async function() {
      await this.basixNFTSale.setFeesReceiver(
        accounts[3],
        { from: accounts[0] }
      );
      
      assert.equal(
        await this.basixNFTSale.feesReceiver.call().valueOf(),
        accounts[3],
        'Not changed address value'
      );
    });

    it('not changes when non-owner calls', async function() {
      await expectRevert(
        this.basixNFTSale.setFeesReceiver(
          accounts[3],
          { from: accounts[1] }
        ),
        'Ownable: caller is not the owner'
      );
    });

  });

  describe('createSale', function () {
    it('with image 1 and rarity 2 must works', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      let sale = await this.basixNFTSale.salesMap.call(image, rarity).valueOf();
      assert.equal(
        sale.supply,
        supply,
        'Created sale has not right supply value'
      );
      assert.equal(
        sale.sold,
        0,
        'Created sale has not right sold value'
      );
      assert.equal(
        sale.image,
        image,
        'Created sale has not right image value'
      );
      assert.equal(
        sale.rarity,
        rarity,
        'Created sale has not right rarity value'
      );
      assert.equal(
        sale.basixPrice.toString(),
        basixPrice.toString(),
        'Created sale has not right basixPrice value'
      );
      assert.equal(
        sale.ethPrice.toString(),
        ethPrice.toString(),
        'Created sale has not right ethPrice value'
      );
    });

    it('with image 2 and rarity 6 must fails', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)

      await expectRevert(
        this.basixNFTSale.createSale(
          supply,
          2,
          6,
          basixPrice,
          ethPrice,
          { from: accounts[0] }
        ),
        'BasixNFTSale: Rarity must be between 1 and 5'
      );
    });

    it('with repeated image and rarity must fails', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)

      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await expectRevert(
        this.basixNFTSale.createSale(
          supply,
          image,
          rarity,
          basixPrice,
          ethPrice,
          { from: accounts[0] }
        ),
        'BasixNFTSale: Sale for image and rarity already exists'
      );
    });

  });

  describe('buy', function () {

    it('with not existing image must fails', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)

      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await expectRevert(
        this.basixNFTSale.buy(
          6,
          rarity,
          { value: ethPrice, from: accounts[1] }
        ),
        'BasixNFTSale: Sale for image and rarity not exists'
      );
    });

    it('with not existing rarity must fails', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)

      await this.basixNFTSale.createSale(
        supply,
        image,
        4,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await expectRevert(
        this.basixNFTSale.buy(
          6,
          rarity,
          { value: ethPrice, from: accounts[1] }
        ),
        'BasixNFTSale: Sale for image and rarity not exists'
      );
    });

    it('when not existing Sale must fails', async function() {
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)

      await expectRevert(
        this.basixNFTSale.buy(
          1,
          2,
          { value: ethPrice, from: accounts[1] }
        ),
        'BasixNFTSale: Sale for image and rarity not exists'
      );
    });

    it('with existing Sale works', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[1] }
      );
    });

    it('when already buyed must fails', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[1] }
      );

      async function timeout(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
      }
      await timeout(1000);

      await expectRevert(
        this.basixNFTSale.buy(
          image,
          rarity,
          { value: ethPrice, from: accounts[1] }
        ),
        'BasixNFTSale: Address already buyed in this sale'
      );
    });

    it('when all supply already buyed must fails', async function() {
      const supply = 1;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[2] }
      );

      await expectRevert(
        this.basixNFTSale.buy(
          image,
          rarity,
          { value: ethPrice, from: accounts[1] }
        ),
        'BasixNFTSale: All sale supply has been sold'
      );
    });

    it('moves Basix amount', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      const userBasixBalanceBeforeBuy = await this.basixToken.balanceOf(accounts[1]);

      await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[1] }
      );

      const userBasixBalanceAfterBuy = await this.basixToken.balanceOf(accounts[1]);

      assert.equal(
        userBasixBalanceAfterBuy.toString(),
        (userBasixBalanceBeforeBuy - basixPrice).toString(),
        'Sale price has not been subtracted from user Basix balance'
      );
    });

    it('moves Ethereum amount', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      const ownerEhereumBalanceBeforeBuy = await web3.eth.getBalance(accounts[0]);
      const userEhereumBalanceBeforeBuy = await web3.eth.getBalance(accounts[1]);

      const txInfo = await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[1] }
      );

      const tx = await web3.eth.getTransaction(txInfo.tx);
      const gasCost = Number(tx.gasPrice) * Number(txInfo.receipt.gasUsed);

      const ownerEthereumBalanceAfterBuy = await web3.eth.getBalance(accounts[0]);
      const userEthereumBalanceAfterBuy = await web3.eth.getBalance(accounts[1]);

      assert.equal(
        userEthereumBalanceAfterBuy.toString(),
        subStrings(subStrings(userEhereumBalanceBeforeBuy, ethPrice), gasCost).toString(),
        'Sale price has not been subtracted from user Ethereum balance'
      );

      assert.equal(
        ownerEthereumBalanceAfterBuy.toString(),
        sumStrings(ownerEhereumBalanceBeforeBuy, ethPrice),
        'Sale ethereum price has not been transferred to owner'
      );
    });

    it('token NFT received', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[1] }
      );

      const basixNFT = await this.basixNFT.balanceOf(accounts[1]);

      assert.equal(
        basixNFT.toString(),
        1,
        'BasixNFT has not been transferred'
      );
    });

    it('sold incremented', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[1] }
      );

      let sale = await this.basixNFTSale.salesMap.call(image, rarity).valueOf();
      assert.equal(
        sale.sold,
        1,
        'Sale has not right sold value after buy'
      );
    });

    it('partitipantMap updated', async function() {
      const supply = 3;
      const image = 1;
      const rarity = 2;
      const basixPrice = new BN("1000000000000000000"); // 1 * (10 ** 18)
      const ethPrice = new BN("500000000000000000"); // 0.5 * (10 ** 18)
      
      await this.basixNFTSale.createSale(
        supply,
        image,
        rarity,
        basixPrice,
        ethPrice,
        { from: accounts[0] }
      );

      await this.basixNFTSale.buy(
        image,
        rarity,
        { value: ethPrice, from: accounts[1] }
      );

      let participant = await this.basixNFTSale.partitipantMap.call(accounts[1], image, rarity).valueOf();
      assert.equal(
        participant,
        true,
        'partitipantMap has not updated after buy'
      );
    });
  });

});

function sumStrings(a,b) { 
  return ((BigInt(a)) + BigInt(b)).toString();
}

function subStrings(a,b) { 
  return ((BigInt(a)) - BigInt(b)).toString();
}
