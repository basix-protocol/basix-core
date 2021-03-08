const { expectRevert, expectEvent, BN } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const BasixNFT = artifacts.require("BasixNFT");

contract('BasixNFT', function (accounts) {

  beforeEach(async function () {
    this.basixnft = await BasixNFT.new(
      'BasixNFT',
      'BNFT',
      'https://basix.com/nft/',
      { from: accounts[0] }
    );

    this.tokenIdA = await this.basixnft.mintNFT.call(
      accounts[1],
      1,
      2,
      { from: accounts[0] }
    );
    await this.basixnft.mintNFT(
      accounts[1],
      1,
      2,
      { from: accounts[0] }
    );

    this.tokenIdB = await this.basixnft.mintNFT.call(
      accounts[2],
      9,
      8,
      { from: accounts[0] }
    );
    await this.basixnft.mintNFT(
      accounts[2],
      9,
      8,
      { from: accounts[0] }
    );
    
  });

  describe('BasixNFT', function () {

    it('has a supply of 2 tokens', async function() {
      assert.equal(
        await this.basixnft.totalSupply(),
        2,
        'BasixNFT has not a supply of 2 tokens'
      );
    });

  });

  describe('TokenA', function () {

    it('has image \'1\'', async function() {
      assert.equal(
        await this.basixnft.tokenImage(this.tokenIdA),
        1,
        'TokenA image is not \'1\''
      );
    });

    it('has rarity \'2\'', async function() {
      assert.equal(
        await this.basixnft.tokenRarity(this.tokenIdA),
        2,
        'TokenA rarity is not \'2\''
      );
    });

  });

  describe('TokenB', function () {

    it('has image \'9\'', async function() {
      assert.equal(
        await this.basixnft.tokenImage(this.tokenIdB),
        9,
        'TokenA image is not \'9\''
      );
    });

    it('has rarity \'8\'', async function() {
      assert.equal(
        await this.basixnft.tokenRarity(this.tokenIdB),
        8,
        'TokenA rarity is not \'8\''
      );
    });

  });

  describe('Account 1', function () {

    it('should have TokenA', async function() {
      assert.equal(
        await this.basixnft.ownerOf(this.tokenIdA),
        accounts[1],
        'Account 1 is not owner of TokenA'
      );
    });

    it('transfers TokenA to Account 2', async function() {
      await this.basixnft.transferFrom(
        accounts[1],
        accounts[2],
        this.tokenIdA,
        { from: accounts[1] }
      );
      assert.equal(
        await this.basixnft.ownerOf(this.tokenIdA),
        accounts[2],
        'Account 2 is not owner of TokenA'
      );
    });

  });

  describe('Account 2', function () {

    it('should have TokenB', async function() {
      assert.equal(
        await this.basixnft.ownerOf(this.tokenIdB),
        accounts[2],
        'Account 2 is not owner of TokenA'
      );
    });

    it('should can not to tranfer TokenA', async function() {
      await expectRevert(
        this.basixnft.transferFrom(
          accounts[1],
          accounts[2],
          this.tokenIdA,
          { from: accounts[2] }
        ),
        'ERC721: transfer caller is not owner nor approved'
      );
    });

  });

  describe('Account 2', function () {

    it('should can not to mint a token', async function() {
      await expectRevert(
        this.basixnft.mintNFT(
          accounts[2],
          30,
          40,
          { from: accounts[2] }
        ),
        'Ownable: caller is not the owner'
      );
    });

  });

});
