'use strict';

const Reservation = artifacts.require('./Reservation.sol');

var expectThrow = async function(promise) {
    try {
        await promise;
    } catch (error) {
        // TODO: Check jump destination to destinguish between a throw
        //       and an actual invalid jump.
        const invalidOpcode = error.message.search('invalid opcode') >= 0;
        // TODO: When we contract A calls contract B, and B throws, instead
        //       of an 'invalid jump', we get an 'out of gas' error. How do
        //       we distinguish this from an actual out of gas event? (The
        //       testrpc log actually show an 'invalid jump' event.)
        const outOfGas = error.message.search('out of gas') >= 0;
        assert(
            invalidOpcode || outOfGas,
            "Expected throw, got '" + error + "' instead",
        );
        return;
    }
    assert.fail('Expected throw not received');
};

contract('Reservation', function (accounts) {
    var instance;

    var owner = accounts[0];
    var guest1 = accounts[1];
    var guest2 = accounts[2];
    var guest3 = accounts[3];

    it('creates a contract', async function() {
        instance = await Reservation.new(1564555780, 1, 2, 1600000000, 200000000);
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

    it('makes a second reservation', async function() {
        await instance.makeReservation({value: web3.toWei(800, 'mwei'), from: guest2});
        var guestCount = await instance.guestsCount();
        assert.equal(guestCount.toString(), 2);
    });

    it('cannot make a third reservation', async function() {
        await expectThrow(instance.makeReservation({value: web3.toWei(800, 'mwei'), from: guest3}));
    });


});