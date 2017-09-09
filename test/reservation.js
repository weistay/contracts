'use strict';

const Reservation = artifacts.require('./Reservation.sol');

var expectThrow = require('./helpers/expectThrow');

contract('Reservation', function (accounts) {
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
    var totalInWei = 1600000000;
    var ddInWei = 200000000;
    var expiryTimestamp = currentTimestamp + 120; // Expires in 2 minutes since we want to test expiry stuff too

    it('creates a contract', async function() {
        instance = await Reservation.new(arrivalDate, nights, guestsTotal, totalInWei, ddInWei, expiryTimestamp);
    });

    it('makes sure the amount per guest is correct', async function() {
        var fee = await instance.amountPerGuest();
        assert.equal(fee.toString(), web3.toWei(800, 'mwei'));
    });

    it('makes first reservation', async function() {
        await instance.makeReservation({value: web3.toWei(800, 'mwei'), from: guest1});
        var guestCount = await instance.guestsCount();
        assert.equal(guestCount.toString(), 1);
    });

    it('guest cannot withdraw an amount whilst reversion open', async function() {
        await expectThrow(instance.withdrawPaidAmount({from: guest1}));
    });

    it('makes a second reservation', async function() {
        await instance.makeReservation({value: web3.toWei(800, 'mwei'), from: guest2});
        var guestCount = await instance.guestsCount();
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

});