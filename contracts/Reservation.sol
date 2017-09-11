pragma solidity ^0.4.16;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";


contract Reservation is Ownable {

    using SafeMath for uint256;

    enum States {
        ReservationOpen,
        ReservationBooked,
        ReservationCancelled,
        BookingActive,
        BookingCompleted,
        BookingDisputed
    }

    uint public guestTotal;

    // Calculated on Constructor
    uint public amountPerGuest;

    uint public totalAmountPaid;
    uint public totalAmountRefunded;
    uint public reservationTotalAmount;

    uint public nights;
    uint public arrivalTimestamp;
    uint public departureTimestamp;
    uint public createdTimestamp = block.timestamp;

    // When the reservation shall expire if not booked
    uint public expiryTimestamp;

    struct Guest {
        address guestAddress;
        uint amountPaid;
        uint paidTimestamp;
        bool exists;
        bool refunded;
    }

    uint public guestsCount = 0;
    mapping(address => Guest) public guests;

    // Start in open reservation state
    States public currentState = States.ReservationOpen;

    function Reservation(
        uint _arrivalTimestamp,
        uint _nights,
        uint _guestTotal,
        uint _reservationTotalAmount,
        uint _expiryTimestamp
    ) {
        require(_nights > 0 && _nights < 30);
        require(_guestTotal > 0 && _guestTotal < 100);

        require(_arrivalTimestamp > createdTimestamp);
        require(_expiryTimestamp > createdTimestamp && _expiryTimestamp < _arrivalTimestamp);

        require(_reservationTotalAmount > 0 && _reservationTotalAmount < 100 ether);

        // Ensure that the total amount will not result in a higher amount than the total
        amountPerGuest = _reservationTotalAmount / _guestTotal;
        require(amountPerGuest > 0 && amountPerGuest <= _reservationTotalAmount);

        expiryTimestamp = _expiryTimestamp;

        nights = _nights;
        guestTotal = _guestTotal;

        arrivalTimestamp = _arrivalTimestamp;
        departureTimestamp = _arrivalTimestamp + (_nights * 86400);

        reservationTotalAmount = _reservationTotalAmount;
    }

    modifier atCurrentState(States _currentState) {
        checkIfBookingActive();

        require(currentState == _currentState);
        _;
    }

    // Requires guest slots to be open
    modifier guestLimitNotReached() {
        require(guestsCount < guestTotal);
        _;
    }

    // Default function is to throw as we don't want any funny business
    function() payable {
        revert();
    }

    // Can be called to update the contracts state if so desired
    function ping() external {
        checkIfBookingActive();
    }

    // Allow a reservation to be made if the contract is in ReservationOpen state AND guest limit is not reached
    // However, if we reach the guest limit with this reservation, this contract needs to move to the Booked state.
    // When allowing a reservation we will need to check that they have paid the correct amount per guest
    function makeReservation() payable atCurrentState(States.ReservationOpen) guestLimitNotReached {
        // Contracts are not allowed to enter
        require(!isContract(msg.sender));
		// Each guest cannot pay more than the allocated amount
        require(msg.value == amountPerGuest);
        // Whole contract not overpaid
        require(totalAmountPaid < reservationTotalAmount);
        // Make sure guest has not already paid, use false check as its more clear
        require(guests[msg.sender].exists == false);

        guestsCount ++;
        totalAmountPaid = totalAmountPaid + msg.value;

        guests[msg.sender].guestAddress = msg.sender;
        guests[msg.sender].amountPaid = msg.value;
        guests[msg.sender].paidTimestamp = block.timestamp;
        guests[msg.sender].exists = true;

        // We now need to check if this contract can move forward
        performReservationOpenStateCheck();
    }

    // The cancel action is for the owner of the contract; only works in open/booked states
    // It will change the state to cancelled where all guests will be able to withdraw their ether
    // The only is only allowed to cancel a booked reservation if it is before the expiry time
    function cancelReservation() external onlyOwner {
        // make sure to check that we can't cancel it when guests are in the property
        checkIfBookingActive();

        require(currentState == States.ReservationOpen || currentState == States.ReservationBooked);
        require(isReservationExpired() == false); // Not past expiry or owner cannot cancel the booking

        currentState = States.ReservationCancelled;
    }

    // Let guests withdraw their amount if the reservation is cancelled
    function withdrawPaidAmount() external atCurrentState(States.ReservationCancelled) {
        // Make sure this sender exists
        require(guests[msg.sender].exists);
        require(guests[msg.sender].refunded == false);

        // Set refunded to true now before we send
        guests[msg.sender].refunded = true;
        uint refundAmount = guests[msg.sender].amountPaid;
        totalAmountRefunded = totalAmountRefunded + refundAmount;

        if (!msg.sender.send(refundAmount)) {
            // If the send failed then reset now
            guests[msg.sender].refunded = false;
            totalAmountRefunded = totalAmountRefunded - refundAmount;
        }
    }

    function ownerWithdrawAmountOwed() external onlyOwner atCurrentState(States.BookingCompleted) {

    }

    function destroy() onlyOwner {
        selfdestruct(owner);
    }

    function destroyAndSend(address _recipient) onlyOwner {
        selfdestruct(_recipient);
    }

    function performReservationOpenStateCheck() internal {
        if (currentState != States.ReservationOpen) {
            return;
        }

        // Requirements to move from open to booked is the guest total fulfilled & total amount met
        if (isGuestCapacityMet() && isTotalAmountPaid()) {
            currentState = States.ReservationBooked;
        } else if (block.timestamp > expiryTimestamp) {
            // Reservation conditions have not been met to convert to booked & now it must be cancelled
            currentState = States.ReservationCancelled;
        }
    }

    // Booking Active is progressed to automatically
    function checkIfBookingActive() internal {
        if (currentState == States.ReservationBooked) {
            if (block.timestamp > arrivalTimestamp) {
                currentState = States.BookingActive;
            }
        }
    }

    function isReservationExpired() view returns (bool) {
        return block.timestamp > expiryTimestamp;
    }

    function isGuestCapacityMet() view returns (bool) {
        return guestsCount == guestTotal;
    }

    function isTotalAmountPaid() view returns (bool) {
        return totalAmountPaid == reservationTotalAmount;
    }
    
    function isContract(address addr) view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function getBalance() view returns (uint) {
        return this.balance;
    }

}
