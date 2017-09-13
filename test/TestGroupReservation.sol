pragma solidity ^0.4.16;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/GroupReservation.sol";


contract TestGroupReservation {

    function testContractCreation() {
        GroupReservation gr = new GroupReservation(
            block.timestamp + 30 days,
            7,
            800000000,
            4,
            2,
            block.timestamp + 2 minutes
        );

        Assert.equal(gr.costPerGuest(), 800000000, "Each guest should pay 8 gwei");
    }

}
