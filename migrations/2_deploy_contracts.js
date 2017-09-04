var Reservation = artifacts.require("./Reservation.sol");

module.exports = function(deployer) {
  //deployer.deploy(ConvertLib);
  //deployer.link(ConvertLib, MetaCoin);
  deployer.deploy(Reservation);
};
