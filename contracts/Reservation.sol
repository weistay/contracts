pragma solidity ^0.4.11;

import "zeppelin-solidity/contracts/Ownable.sol";
import "zeppelin-solidity/contracts/SafeMath.sol";

contract ReservationContract is Ownable, SafeMath {

    enum States {
        OpenReservation,
        BookedReservation,
        CancelledReservation,
        BookingActive,
        BookingFinished,
        BookingDisputed
    }

    uint public guestCount;
    uint public reservationTotalAmount;
    uint public refundableDamageDepositAmount;

    uint public nights;
    uint public arrivalTimestamp;
    uint public createdTimestamp = now;

    States public currentState = States.OpenReservation;

    function ReservationContract(uint arrivalTimestamp, uint nights, uint guestCount, uint reservationTotalAmount, uint refundableDamageDepositAmount) {
        this.nights = nights;
        this.guestCount = guestCount;
        this.arrivalTimestamp = arrivalTimestamp;
        this.reservationTotalAmount = reservationTotalAmount;
        this.refundableDamageDepositAmount = refundableDamageDepositAmount;
    }

    modifier atCurrentState(States _currentState) {
        require(currentState == _currentState);
        _;
    }

    function test() payable atCurrentState(States.OpenReservation) {

    }

}