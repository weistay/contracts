pragma solidity ^0.4.11;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Reservation.sol";

contract TestReservation {

    function testContractCreation() {
        Reservation tReservation = new Reservation(1564555780, 1, 1, 1600000000, 200000000);

        Assert.equal(tReservation.amountPerGuest(), 2 ether, "Each guest should pay 2 ether");
    }

}
