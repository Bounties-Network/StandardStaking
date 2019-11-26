const StandardStaking = artifacts.require("../contracts/StandardStaking");

const utils = require('./helpers/Utils');

const BN = require('bignumber.js');

contract('StandardStaking', function(accounts) {


  it("Verifies that the StandardStaking registry works", async () => {

    let registry = await StandardStaking.new();

  });
  it("Verifies that I can create a new stake locking up ETH", async () => {

    let registry = await StandardStaking.new();

    await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 180, 18, 2528821098, "data", {value: 1818, from: accounts[5]});

    let stakes = await registry.stakes();

    assert(stakes.length == 1);
    assert(stakes[0].staker == accounts[0]);
    assert(stakes[0].arbiters == [accounts[1], accounts[2], accounts[3]]);
    assert(stakes[0].stakeAmount == 1818);
    assert(stakes[0].arbiterFee == 180);
    assert(stakes[0].griefingFee == 18);
    assert(stakes[0].deadline == 2528821098);

  });

  it("Verifies that I can't create a stake of 0", async () => {

    let registry = await StandardStaking.new();

    try {
      await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 0, 0, 0, 2528821098, "data", {value: 0, from: accounts[5]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");

  });

  it("Verifies that I can't create a stake of whose fees are too large", async () => {

    let registry = await StandardStaking.new();

    try {
      await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 10, 10, 10, 2528821098, "data", {value: 10, from: accounts[5]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");

  });

  it("Verifies that I can't create a stake with 0 arbiters", async () => {

    let registry = await StandardStaking.new();

    try {
      await registry.createStake(accounts[0], [], 1818, 10, 10, 2528821098, "data", {value: 1818, from: accounts[5]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");

  });

  it("Verifies that I can't create a stake with a passed deadline", async () => {

    let registry = await StandardStaking.new();

    try {
      await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 10, 10, 10, "data", {value: 1818, from: accounts[5]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");

  });

  it("Verifies that I can't create a stake without locking up sufficient funds", async () => {

    let registry = await StandardStaking.new();

    try {
      await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 10, 10, 2528821098, "data", {value: 18, from: accounts[5]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");

  });

  it("Verifies that I can open a claim against a stake", async () => {

    let registry = await StandardStaking.new();

    await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 10, 10, 2528821098, "data", {value: 1818, from: accounts[5]});

    await registry.openClaim(0, 18, "data2", {value: 38, from: accounts[6]});

    let stake = await registry.stakes(0);

    assert(stake.claims[0].claimant == accounts[6]);
    assert(stake.claims[0].arbiter == '0x0000000000000000000000000000000000000000');
    assert(stake.claims[0].claimAmount == 18);
    assert(stake.claims[0].ruled == false);
    assert(stake.claims[0].correct == false);
  });

  it("Verifies that I can't open a claim against a stake that's out of bounds", async () => {

    let registry = await StandardStaking.new();

    await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 10, 10, 2528821098, "data", {value: 1818, from: accounts[5]});

    try {
      await registry.openClaim(1, 18, "data2", {value: 38, from: accounts[6]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");
  });

  it("Verifies that I can't open a claim against a stake without depositing enough tokens", async () => {

    let registry = await StandardStaking.new();

    await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 10, 10, 2528821098, "data", {value: 1818, from: accounts[5]});

    try {
      await registry.openClaim(0, 18, "data2", {value: 38, from: accounts[6]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");
  });

  it("Verifies that I can't open a claim for an amount that's larger than the stake", async () => {

    let registry = await StandardStaking.new();

    await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 10, 10, 2528821098, "data", {value: 1818, from: accounts[5]});

    try {
      await registry.openClaim(0, 1799, "data2", {value: 1819, from: accounts[6]});

    } catch (error){
      return utils.ensureException(error);
    }
    assert(false, "Should have thrown an error");
  });

  it("Verifies that I can rule on a claim", async () => {

    let registry = await StandardStaking.new();

    await registry.createStake(accounts[0], [accounts[1], accounts[2], accounts[3]], 1818, 10, 10, 2528821098, "data", {value: 1818, from: accounts[5]});

    await registry.openClaim(0, 18, "data2", {value: 38, from: accounts[6]});

    await registry.ruleOnClaim(0, 0, 1, true, "data3", {from: accounts[2]});

    let claim = await registry.stakes(0).claims[0];

    assert(claim.ruled == true);
    assert(claim.correct == true);
    assert(claim.arbiter == accounts[2]);
  });



});
