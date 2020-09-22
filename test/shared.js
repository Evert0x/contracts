const { time } = require('@openzeppelin/test-helpers');
const { accounts } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const [from] = accounts;

module.exports = {
    REWARD_POLL_DURATION: 180,
    WITHDRAW_POLL_DURATION: 180,
    REWARD_AMOUNT: '50',
    DEPOSIT_AMOUNT: '1000',
    MINT_AMOUNT: '5000',
    vote: async (poll, agree) => {
        let vote = await poll.votesByAddress(from);

        expect(vote.time.toNumber()).to.equal(0);

        await poll.vote(from, agree, { from });

        vote = await poll.votesByAddress(from);

        expect(vote.time.toNumber()).to.not.equal(0);
        expect(vote.weight.toNumber()).to.equal(1);
    },
    timeTravel: async minutes => {
        const before = (await time.latest()).toNumber();

        await time.increase(time.duration.minutes(minutes + 1));

        const after = (await time.latest()).toNumber();

        expect(after).to.be.above(before);
    },
    finalize: async poll => {
        expect(await poll.finalized()).to.equal(false);

        await poll.tryToFinalize({ from });

        expect(await poll.finalized()).to.equal(true);
    },
};
