'use strict';

const GroupReservation = artifacts.require('./GroupReservation.sol');

var expectThrow = require('./helpers/expectThrow');
var increaseTime = require('./helpers/increaseTime');

contract('group reservation booked and then cancelled', function (accounts) {
    var instance;

    var owner = accounts[0];
    var guest1 = accounts[1];
    var guest2 = accounts[2];
    var guest3 = accounts[3];

    var oneDay = 86400;
    var currentTimestamp = Math.floor(Date.now() / 1000);
    var arrivalDate = currentTimestamp + (oneDay * 30);
    var nights = 7;
    var guestsTotal = 2;
    var guestsMinimum = 1;
    var costPerGuest = 800000000;
    var expiryTimestamp = currentTimestamp + 180;

    it('creates a contract', async function() {
        instance = await GroupReservation.new(arrivalDate, nights, costPerGuest, guestsTotal, guestsMinimum, expiryTimestamp);
    });

    it('makes sure the amount per guest is correct', async function() {
        var fee = await instance.costPerGuest();
        assert.equal(fee.toString(), web3.toWei(800, 'mwei'));
    });

    it('makes first reservation', async function() {
        await instance.makeReservation({value: web3.toWei(800, 'mwei'), from: guest1});
        var guestCount = await instance.currentGuestCount();
        assert.equal(guestCount.toString(), 1);
    });

    it('guest cannot withdraw an amount whilst reversion open', async function() {
        await expectThrow(instance.withdrawPaidAmount({from: guest1}));
    });

    it('will not accept an invalid wei amount', async function() {
        await expectThrow(instance.makeReservation({value: web3.toWei(801, 'mwei'), from: guest2}));
    });

    it('makes a second reservation', async function() {
        await instance.makeReservation({value: web3.toWei(800, 'mwei'), from: guest2});
        var guestCount = await instance.currentGuestCount();
        assert.equal(guestCount.toString(), 2);
    });

    it('cannot make a third reservation', async function() {
        await expectThrow(instance.makeReservation({value: web3.toWei(800, 'mwei'), from: guest3}));
    });

    it('is fully paid and has progressed to reservation booked', async function() {
        var totalAmountPaid = await instance.totalAmountPaid();
        var reservationTotalAmount = await instance.reservationTotalAmount();

        assert.equal(totalAmountPaid.toString(), reservationTotalAmount.toString());

        var currentState = await instance.currentState();
        assert.equal(currentState.toString(), 1); // 1 is reservation booked
    });

    it('guest cannot cancel the reservation', async function() {
        await expectThrow(instance.cancelReservation({from: guest1}));
    });

    it('owner cancels reservation', async function() {
        await instance.cancelReservation({from: owner});

        var currentState = await instance.currentState();
        assert.equal(currentState.toString(), 2); // 2 is reservation cancelled
    });

    it('guest can withdraw the amount that they put in', async function() {
        await instance.withdrawPaidAmount({from: guest1});

        var remainingBalance = await instance.getBalance();
        assert.equal(remainingBalance.toString(), web3.toWei(800, 'mwei'));

        await instance.withdrawPaidAmount({from: guest2});
    });

    it('reservation contract should have 0 balance', async function() {
        var remainingBalance = await instance.getBalance();
        assert.equal(remainingBalance.toString(), 0);
    });

});



contract('group reservation booked and completed', function (accounts) {
    var instance2;

    var owner = accounts[0];
    var guest1 = accounts[1];
    var guest2 = accounts[2];
    var guest3 = accounts[3];

    var oneDay = 86400;
    var currentTimestamp = Math.floor(Date.now() / 1000);
    var arrivalDate = currentTimestamp + oneDay;
    var nights = 7;
    var guestsTotal = 2;
    var guestsMinimum = 1;
    var costPerGuest = 800000000;
    var expiryTimestamp = currentTimestamp + 180;

    it('creates a contract', async function() {
        instance2 = await GroupReservation.new(arrivalDate, nights, costPerGuest, guestsTotal, guestsMinimum, expiryTimestamp);
    });

    it('makes first reservation', async function() {
        await instance2.makeReservation({value: costPerGuest, from: guest1});
        var guestCount = await instance2.currentGuestCount();
        assert.equal(guestCount.toString(), 1);
    });

    it('makes a second reservation', async function() {
        await instance2.makeReservation({value: costPerGuest, from: guest2});
        var guestCount = await instance2.currentGuestCount();
        assert.equal(guestCount.toString(), 2);
    });

    it('is fully paid and has progressed to reservation booked', async function() {
        var totalAmountPaid = await instance2.totalAmountPaid();
        var reservationTotalAmount = await instance2.reservationTotalAmount();

        assert.equal(totalAmountPaid.toString(), reservationTotalAmount.toString());

        var currentState = await instance2.currentState();
        assert.equal(currentState.toString(), 1); // 1 is reservation booked
    });

    /*it('the contract will advance to the active state', async function() {
        increaseTime.increaseTimeTestRPC(increaseTime.duration.days(2));
        await instance2.ping();
        var currentState = await instance2.currentState();
        assert.equal(currentState.toString(), 2);
    });
*/
});




