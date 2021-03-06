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
    VOTER: '0xaf9d56684466fcFcEA0a2B7fC137AB864d642946',
    VOTER_PK: '0x97093724e1748ebfa6aa2d2ec4ec68df8678423ab9a12eb2d27ddc74e35e5db9',
    vote: async (poll, voter, agree, nonce, sig) => {
        let vote = await poll.votesByAddress(voter);

        expect(vote.time.toNumber()).to.equal(0);

        await poll.vote(voter, agree, nonce, sig, { from });

        vote = await poll.votesByAddress(voter);

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
