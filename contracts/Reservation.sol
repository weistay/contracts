pragma solidity ^0.4.11;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

contract Reservation is Ownable {

    using SafeMath for uint256;

    enum States {
    OpenReservation,
    BookedReservation,
    CancelledReservation,
    BookingActive,
    BookingFinished,
    BookingDisputed
    }

    uint public guestTotal;

    // Calculated on Constructor
    uint public amountPerGuest;

    uint public reservationTotalAmount;
    uint public refundableDamageDepositAmount;
    uint public totalAmountPaid;

    uint public nights;
    uint public arrivalTimestamp;
    uint public departureTimestamp;
    uint public createdTimestamp = block.timestamp;

    struct Guest {
    address guestAddress;
    uint amountPaid;
    uint paidTimestamp;
    }

    uint public guestsCount = 0;
    mapping(address => Guest) public guests;

    // Start in open reservation state
    States public currentState = States.OpenReservation;

    function Reservation(uint nArrivalTimestamp, uint nNights, uint nGuestTotal, uint nReservationTotalAmount, uint nRefundableDamageDepositAmount) {
        require(nNights > 0 && nNights < 30);
        require(nGuestTotal > 0 && nGuestTotal < 100);
        require(nArrivalTimestamp > createdTimestamp);
        require(nReservationTotalAmount > 0 && nReservationTotalAmount < 100 ether);
        require(nRefundableDamageDepositAmount >= 0 && nRefundableDamageDepositAmount < nReservationTotalAmount);

        amountPerGuest = nReservationTotalAmount / nGuestTotal;
        // Ensure that the total amount will not result in a higher amount than the total
        require(amountPerGuest > 0 && (amountPerGuest * nGuestTotal) <= nReservationTotalAmount);

        nights = nNights;
        guestTotal = nGuestTotal;

        arrivalTimestamp = nArrivalTimestamp;
        departureTimestamp = nArrivalTimestamp + (nNights * 86400);

        reservationTotalAmount = nReservationTotalAmount;
        refundableDamageDepositAmount = nRefundableDamageDepositAmount;
    }

    modifier atCurrentState(States _currentState) {
        require(currentState == _currentState);
        _;
    }

    // Requires guest slots to be open
    modifier guestLimitNotReached() {
        require(guestsCount < guestTotal);
        _;
    }

    // Allow a reservation to be made if the contract is in OpenReservation state AND guest limit is not reached
    // However, if we reach the guest limit with this reservation, this contract needs to move to the Booked state.
    // When allowing a reservation we will need to check that they have paid the correct amount per guest
    function makeReservation() payable atCurrentState(States.OpenReservation) guestLimitNotReached {
        // Contracts are not allowed to enter
        require(!isContract(msg.sender));
        
        require(msg.value == amountPerGuest);

        guestsCount = guestsCount + 1;
        totalAmountPaid = totalAmountPaid + msg.value;

        guests[msg.sender].guestAddress = msg.sender;
        guests[msg.sender].amountPaid = msg.value;
        guests[msg.sender].paidTimestamp = block.timestamp;

        // We now need to check if this contract can move forward
        performOpenReservationStateCheck();

    }

    function performOpenReservationStateCheck() internal {
        if (currentState != States.OpenReservation) {
            return;
        }

        // Requirements to move from open to booked is the guest total fulfilled & total amount met
        if (isGuestCapacityMet() && isTotalAmountPaid()) {
            currentState = States.BookedReservation;
        }
    }

    function isGuestCapacityMet() returns (bool) {
        return guestsCount == guestTotal;
    }

    function isTotalAmountPaid() returns (bool) {
        return totalAmountPaid == reservationTotalAmount;
    }
    
    function isContract(address addr) returns (bool) {
      uint size;
      assembly { size := extcodesize(addr) }
      return size > 0;
    }

}
