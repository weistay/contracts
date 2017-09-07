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

    function Reservation(
        uint _arrivalTimestamp,
        uint _nights,
        uint _guestTotal,
        uint _reservationTotalAmount,
        uint _refundableDamageDepositAmount
    ) {
        require(_nights > 0 && _nights < 30);
        require(_guestTotal > 0 && _guestTotal < 100);
        require(_arrivalTimestamp > createdTimestamp);
        require(_reservationTotalAmount > 0 && _reservationTotalAmount < 100 ether);
        require(_refundableDamageDepositAmount >= 0 && _refundableDamageDepositAmount < _reservationTotalAmount);

        amountPerGuest = _reservationTotalAmount / nGuestTotal;
        // Ensure that the total amount will not result in a higher amount than the total
        require(amountPerGuest > 0 && (amountPerGuest * _guestTotal) <= _reservationTotalAmount);

        nights = _nights;
        guestTotal = _guestTotal;

        arrivalTimestamp = _arrivalTimestamp;
        departureTimestamp = _arrivalTimestamp + (nNights * 86400);

        reservationTotalAmount = _reservationTotalAmount;
        refundableDamageDepositAmount = _refundableDamageDepositAmount;
    }

    modifier atCurrentState(States _currentState) {
        checkIfBookingActiveOrFinished();

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
        require(msg.value == amountPerGuest);

        guestsCount = guestsCount + 1;
        totalAmountPaid = totalAmountPaid + msg.value;

        guests[msg.sender].guestAddress = msg.sender;
        guests[msg.sender].amountPaid = msg.value;
        guests[msg.sender].paidTimestamp = block.timestamp;

        // We now need to check if this contract can move forward
        performOpenReservationStateCheck();
    }

    function cancelReservation() {
        require(currentState == States.OpenReservation || currentState == States.BookedReservation);


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

    // Booking Active/Finished are time based states, and can only be set if the current
    // states are booked reservation or booking active
    function checkIfBookingActiveOrFinished() internal {
        if (currentState == States.BookedReservation || currentState == States.BookingActive) {
            if (block.timestamp > arrivalTimestamp && block.timestamp < departureTimestamp) {
                // Currently in the property
                currentState = States.BookingActive;
            } else if (block.timestamp > departureTimestamp) {
                currentState = States.BookingFinished;
            }
        }
    }

    function isGuestCapacityMet() returns (bool) {
        return guestsCount == guestTotal;
    }

    function isTotalAmountPaid() returns (bool) {
        return totalAmountPaid == reservationTotalAmount;
    }

}