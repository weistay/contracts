# Weistay Rental Contracts

This repository will contain the contracts used for renting rental properties.

Below are some quick typed up notes to help with designing the contracts

## Rental Flow

Generally the flow is as follows:

1. Property is booked for certain amount of nights
2. A payment is made for the deposit and/or balance depending how close the booking is (balance is usually around 30-60 days in advance). This balance may include a refundable damage deposit
3. Guests arrive and then depart
4. Property is cleaned/inspected and if no damage is found then the damage deposit is refunded otherwise a portion up to the full amount can be taken.

These simple steps do leave a lot of edge cases, in the initial weistay version there will be no concept of deposit/balances only the total amount that is required.

### Splitting up the payments

Since the weistay idea is about sharing a property with like-minded individuals who at-least some of them should be strangers, the full payment for the property needs to be split up into multiple payments.

Depending on the property, the payment may be fixed per person so any number of individuals can stay, whereas other properties charge a flat fee for a week so regardless of how many guests, each one will need to pay their share. With the latter method a guest limit will need to be reached for the contract to progress any further.

### Stages in the contract

Right now we have the current 'states' of the reservation

 - Reservation Open
 - Reservation Booked
 - Reservation Cancelled
 
 - Booking Active
 - Booking Finished
 - Booking Disputed
 
A reservation transforms into a booking when the guests have actually arrived at the property.
 
[reservation-flow]: https://github.com/weistay/contracts/blob/master/documents/reservation-flow.png?raw=true "Reservation Flow"