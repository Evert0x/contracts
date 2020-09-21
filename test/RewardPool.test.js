const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { vote, timeTravel, finalize, REWARD_POLL_DURATION } = require('./shared');
const THXToken = contract.fromArtifact('THXToken');
const RewardPool = contract.fromArtifact('RewardPool');

let token = null;
let pool = null;
let reward = null;

describe('Reward Pool', function() {
    const [from] = accounts;

    before(async () => {
        const amount = web3.utils.toWei('1000');

        token = await THXToken.new({ from });
        pool = await RewardPool.new({ from });

        await pool.initialize(from, token.address, { from });
        await token.mint(from, amount, { from });
    });

    it('can set the owner to ' + from, async function() {
        const owner = await pool.owner();
        expect(owner).to.equal(from);
    });

    it('can make a deposit of 1000 THX', async function() {
        const amount = web3.utils.toWei('5000');
        const oldBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        await token.mint(from, amount, { from });
        await token.approve(pool.address, amount, { from });
        await pool.deposit(amount, { from });

        const newBalance = web3.utils.fromWei(await token.balanceOf(pool.address));

        expect(parseInt(newBalance, 10)).to.be.above(parseInt(oldBalance, 10));
    });

    it('expects the initial duration to be 0', async function() {
        const duration = await pool.rewardPollDuration();

        expect(parseInt(duration, 10)).to.equal(0);
    });

    it('can set the reward poll duration to ' + REWARD_POLL_DURATION + ' seconds', async function() {
        await pool.setRewardPollDuration(REWARD_POLL_DURATION, { from });

        const duration = await pool.rewardPollDuration();

        expect(duration.toNumber()).to.equal(REWARD_POLL_DURATION);
    });

    it('can make ' + accounts[1] + 'a member', async function() {
        const amount = web3.utils.toWei('100');

        await pool.addMember(accounts[1], { from });

        expect(await pool.isManager(from)).to.equal(true);
        expect(await pool.isMember(accounts[1])).to.equal(true);

        await pool.proposeReward(amount, accounts[1], { from });
    });

    it('can propose a 100 THX reward for ' + accounts[1], async function() {
        const amount = web3.utils.toWei('100');

        expect(await pool.isMember(from)).to.equal(true);
        expect(await pool.isMember(accounts[1])).to.equal(true);

        await pool.proposeReward(amount, accounts[1], { from });
    });

    it('beneficiary can see its rewards address in the reward', async function() {
        const rewardAddress = await pool.rewardsOf(accounts[1], 0);

        reward = contract.fromArtifact('RewardPoll', rewardAddress);

        expect(reward.address).to.equal(rewardAddress);
    });
    it('can vote for a reward claim', async () => vote(reward, true));
    it('can travel ' + REWARD_POLL_DURATION + 's in time', async () => timeTravel(REWARD_POLL_DURATION / 60));
    it('can finalize the reward poll', async () => finalize(reward));
    it('can withdraw the reward', async function() {
        const oldBeneficiaryBalance = await token.balanceOf(accounts[1]);
        const oldRewardPoolBalance = await token.balanceOf(pool.address);

        await reward.withdraw({ from: accounts[1] });

        const newBeneficiaryBalance = await token.balanceOf(accounts[1]);
        const newRewardPoolBalance = await token.balanceOf(pool.address);

        expect(parseInt(newRewardPoolBalance, 10)).to.lessThan(parseInt(oldRewardPoolBalance, 10));
        expect(parseInt(newBeneficiaryBalance, 10)).to.greaterThan(parseInt(oldBeneficiaryBalance, 10));
    });
});
