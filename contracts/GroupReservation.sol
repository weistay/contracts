pragma solidity ^0.4.16;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";


contract GroupReservation is Ownable {

    using SafeMath for uint256;

    enum States {
        ReservationOpen,
        ReservationBooked,
        ReservationCancelled,
        BookingActive,
        BookingFinished,
        BookingCompleted
    }

    uint public costPerGuest;
    uint public guestCountTotal = 0;
    uint public guestCountMinimum = 0;

    uint public totalAmountPaid;
    uint public totalAmountRefunded;

    uint public reservationTotalAmount;
    uint public reservationMinimumAmount;

    uint public nights;
    uint public expiryTimestamp;
    uint public arrivalTimestamp;
    uint public departureTimestamp;

    uint public createdTimestamp = block.timestamp;

    struct Guest {
        address guestAddress;
        uint amountPaid;
        uint paidTimestamp;
        bool exists;
        bool refunded;
    }

    uint public currentGuestCount = 0;

    mapping(address => Guest) public currentGuests;

    // Start in open reservation state
    States public currentState = States.ReservationOpen;

    function GroupReservation(
        uint _arrivalTimestamp,
        uint _nights,
        uint _costPerGuest,
        uint _guestCountTotal,
        uint _guestCountMinimum,
        uint _expiryTimestamp
    ) {
        require(_nights > 0 && _nights < 30);
        require(_guestCountMinimum <= _guestCountTotal);
        require(_guestCountTotal > 0 && _guestCountTotal < 100);

        require(_arrivalTimestamp > createdTimestamp);
        require(_expiryTimestamp > createdTimestamp && _expiryTimestamp < _arrivalTimestamp);

        require(_costPerGuest > 0 && _costPerGuest < 100 ether);

        nights = _nights;
        costPerGuest = _costPerGuest;
        expiryTimestamp = _expiryTimestamp;

        arrivalTimestamp = _arrivalTimestamp;
        departureTimestamp = _arrivalTimestamp + (_nights * 86400);

        guestCountTotal = _guestCountTotal;
        guestCountMinimum = _guestCountMinimum;

        reservationTotalAmount = _costPerGuest * _guestCountTotal;
        reservationMinimumAmount = _costPerGuest * _guestCountMinimum;
    }

    modifier atCurrentState(States _currentState) {
        checkIfBookingActiveOrFinished();

        require(currentState == _currentState);
        _;
    }

    modifier guestLimitNotReached() {
        require(currentGuestCount < guestCountTotal);
        _;
    }

    // Default function is to throw as we don't want any funny business
    function() payable {
        revert();
    }

    // Can be called to update the contracts state if so desired
    function ping() external {
        internalPing();
    }

    function internalPing() internal {
        performReservationOpenStateCheck();
        checkIfBookingActiveOrFinished();
    }

    // Allow a reservation to be made if the contract is in ReservationOpen state AND guest limit is not reached
    // However, if we reach the guest limit with this reservation, this contract needs to move to the Booked state.
    // When allowing a reservation we will need to check that they have paid the correct amount per guest
    function makeReservation() payable atCurrentState(States.ReservationOpen) guestLimitNotReached {
        // Contracts are not allowed to enter
        require(!isContract(msg.sender));
		// Each guest has to pay the exact amount or reject
        require(msg.value == costPerGuest);
        // Make sure guest has not already paid, use false check as its more clear
        require(currentGuests[msg.sender].exists == false);

        currentGuestCount ++;
        totalAmountPaid = totalAmountPaid + msg.value;

        currentGuests[msg.sender].guestAddress = msg.sender;
        currentGuests[msg.sender].amountPaid = msg.value;
        currentGuests[msg.sender].paidTimestamp = block.timestamp;
        currentGuests[msg.sender].exists = true;

        // We now need to check if this contract can move forward
        performReservationOpenStateCheck();
    }

    // The cancel action is for the owner of the contract; only works in open/booked states
    // It will change the state to cancelled where all guests will be able to withdraw their ether
    // The only is only allowed to cancel a booked reservation if it is before the expiry time
    function cancelReservation() external onlyOwner {
        // make sure to check that we can't cancel it when guests are in the property
        internalPing();

        require(canCancelReservation());

        currentState = States.ReservationCancelled;
    }

    // Let guests withdraw their amount if the reservation is cancelled
    function withdrawPaidAmount() external atCurrentState(States.ReservationCancelled) {
        // Make sure this sender exists
        require(currentGuests[msg.sender].exists);
        require(currentGuests[msg.sender].refunded == false);

        // Set refunded to true now before we send
        currentGuests[msg.sender].refunded = true;
        uint refundAmount = currentGuests[msg.sender].amountPaid;
        totalAmountRefunded = totalAmountRefunded + refundAmount;

        if (!msg.sender.send(refundAmount)) {
            // If the send failed then reset now
            currentGuests[msg.sender].refunded = false;
            totalAmountRefunded = totalAmountRefunded - refundAmount;
        }
    }

    function ownerWithdrawAmountOwed() external onlyOwner {
        // Make sure the state is correct
        internalPing();

        require(canOwnerWithdrawAmountOwed());

        // Now we shall set the state to complete as the owner has withdrawn their balance
        currentState = States.BookingCompleted;

        if (!msg.sender.send(this.balance)) {
            // Revert
            currentState = States.BookingFinished;
        }
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
        if (isGuestCountTotalMet()) {
            currentState = States.ReservationBooked;
        } else if (isReservationExpired() && isGuestCountMinimumMet()) {
            // Here we need to check if the reservation expires BUT with the minimum required amount,
            // which will turn the state to reservation booked
            currentState = States.ReservationCancelled;
        } else if (isReservationExpired()) {
            // Reservation conditions have not been met to convert to booked & now it must be cancelled
            currentState = States.ReservationCancelled;
        }
    }

    // Booking Active is progressed to automatically
    function checkIfBookingActiveOrFinished() internal {
        if (currentState == States.ReservationBooked) {
            if (block.timestamp > arrivalTimestamp) {
                currentState = States.BookingActive;
            }
        }

        // Check if finished from both states as active could have been skipped, then check if the
        // guests have left as that will leave it in a finished state
        if (
            (
                currentState == States.ReservationBooked ||
                currentState == States.BookingActive
            ) &&
            block.timestamp > departureTimestamp
        ) {
            currentState = States.BookingFinished;
        }
    }

    function canCancelReservation() view returns (bool) {
        return
            (currentState == States.ReservationOpen || currentState == States.ReservationBooked) &&
            isReservationExpired() == false // Not past expiry or owner cannot cancel the booking
        ;
    }

    function canOwnerWithdrawAmountOwed() view returns (bool) {
        require(currentState == States.BookingFinished);
    }

    function isReservationExpired() view returns (bool) {
        return block.timestamp > expiryTimestamp;
    }

    function isGuestCountTotalMet() view returns (bool) {
        return currentGuestCount == guestCountTotal;
    }

    function isGuestCountMinimumMet() view returns (bool) {
        return currentGuestCount <= guestCountMinimum;
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
