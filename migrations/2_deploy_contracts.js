var StandardStaking = artifacts.require("../contacts/StandardStaking.sol");

module.exports = function(deployer) {
  deployer.deploy(StandardStaking);
};
