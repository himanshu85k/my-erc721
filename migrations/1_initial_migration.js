const Migrations = artifacts.require("MyERC721Token");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};
