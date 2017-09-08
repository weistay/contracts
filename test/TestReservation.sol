pragma solidity ^0.4.16;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Reservation.sol";

contract TestReservation {

    function testContractCreation() {
        Reservation tReservation = new Reservation(
            block.timestamp + 30 days,
            7,
            2,
            1600000000,
            200000000,
            block.timestamp + 2 minutes
        );

        Assert.equal(tReservation.amountPerGuest(), 800000000, "Each guest should pay 8 gwei");
    }

}
