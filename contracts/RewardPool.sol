// contracts/RewardPool.sol
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.4;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';

import './access/Roles.sol';
import './poll/BasePoll.sol';
import './poll/RewardPoll.sol';
import './poll/RewardRulePoll.sol';

contract RewardPool is Initializable, OwnableUpgradeSafe, Roles {
    using SafeMath for uint256;

    struct RewardRule {
        uint256 id;
        uint256 amount;
        RewardRuleState state;
        RewardRulePoll poll;
        uint256 updated;
    }

    struct Withdrawal {
        address reward;
        address beneficiary;
        uint256 timestamp;
    }

    struct Deposit {
        address member;
        uint256 amount;
        uint256 timestamp;
    }

    RewardRule[] public rewardRules;
    RewardPoll[] public rewards;
    Deposit[] public deposits;

    uint256 public rewardPollDuration = 0;
    uint256 public rewardRulePollDuration = 0;

    mapping(address => Deposit[]) public depositsOf;
    mapping(address => Withdrawal[]) public withdrawalsOf;
    mapping(address => RewardPoll[]) public rewardsOf;

    IERC20 public token;

    /*==== IMPORTANT: Do not alter (only extend) the storage layout above this line! ====*/

    enum RewardRuleState { Disabled, Enabled }

    event Withdrawn(address indexed beneficiary, uint256 reward);
    event Deposited(address indexed sender, uint256 amount);
    event RewardRulePollCreated(uint256 id, uint256 proposal, address account);
    event RewardRulePollFinished(uint256 id, uint256 proposal, bool agree);
    event RewardRuleUpdated(uint256 id, RewardRuleState state, uint256 amount);
    event RewardPollCreated(address reward);
    event RewardPollFinished(address reward, bool agree);

    /**
     * @dev Initializes the reward pool and sets the owner. Called when contract upgrades are available.
     * @param _owner Address of the owner of the reward pool
     * @param _tokenAddress Address of the ERC20 token used for this pool
     */
    function initialize(address _owner, address _tokenAddress) public initializer {
        __Ownable_init();
        __Roles_init(_owner);

        transferOwnership(_owner);

        token = IERC20(_tokenAddress);
    }

    /**
     * @dev Get the total amount of deposits in this pool
     */
    function getDepositCount() public view returns (uint256) {
        return deposits.length;
    }

    /**
     * @dev Get the total amount of deposits in this pool
     */
    function getRewardCount() public view returns (uint256) {
        return rewards.length;
    }

    /**
     * @dev Get the total amount of deposits in this pool
     */
    function getRewardRuleCount() public view returns (uint256) {
        return rewardRules.length;
    }

    /**
     * @dev Get the amount of deposits for a given address
     * @param _member Address of the sender of deposits
     */
    function getDepositCountOf(address _member) public view returns (uint256) {
        return depositsOf[_member].length;
    }

    /**
     * @dev Get the amount of deposits for a given address
     * @param _member Address of the sender of deposits
     */
    function getWithdrawalCount(address _member) public view returns (uint256) {
        return withdrawalsOf[_member].length;
    }

    /**
     * @dev Get the amount of rewards for a given address
     * @param _member Address of the sender of deposits
     */
    function getRewardCountOf(address _member) public view returns (uint256) {
        return rewardsOf[_member].length;
    }

    /**
     * @dev Store a deposit in the contract. The tx should be approved prior to calling this method.
     * @param _amount Size of the deposit
     */
    function deposit(uint256 _amount) public onlyMember {
        require(_amount > 0, 'IS_NEGATIVE');
        require(token.balanceOf(msg.sender) >= _amount, 'INSUFFICIENT_BALANCE');

        token.transferFrom(msg.sender, address(this), _amount);

        Deposit memory d;

        d.amount = _amount;
        d.member = msg.sender;
        d.timestamp = now;

        deposits.push(d);
        depositsOf[msg.sender].push(d);

        emit Deposited(msg.sender, _amount);
    }

    /**
     * @dev Set the duration for a reward poll.
     * @param _duration Duration in seconds
     */
    function setRewardPollDuration(uint256 _duration) public {
        require(msg.sender == owner(), 'IS_NOT_OWNER');

        rewardPollDuration = _duration;
    }

    /**
     * @dev Creates a reward rule claim for a rule.
     * @param _duration Duration in seconds
     */
    function setRewardRulePollDuration(uint256 _duration) public {
        require(msg.sender == owner(), 'caller is not owner');

        rewardRulePollDuration = _duration;
    }

    /**
     * @dev Creates a reward claim for a rule.
     * @param _amount Initial size for the reward rule.
     */
    function addRewardRule(uint256 _amount) public {
        require(msg.sender == owner(), 'IS_NOT_OWNER');
        require(_amount >= 0, 'IS_NEGATIVE');

        RewardRule memory rule;

        rule.id = rewardRules.length;
        rule.amount = 0;
        rule.state = RewardRuleState.Disabled;
        rule.poll = _createRewardRulePoll(rewardRules.length, _amount);
        rule.updated = now;

        rewardRules.push(rule);
    }

    /**
     * @dev Starts a reward rule poll
     * @param _id References reward rule
     * @param _amount New size for the reward rule.
     */
    function updateRewardRule(uint256 _id, uint256 _amount) public {
        require(rewardRules[_id].poll.finalized(), 'IS_NOT_FINALIZED');
        require(isMember(msg.sender), 'IS_NOT_MEMBER');
        require(_amount >= 0, 'IS_NEGATIVE');
        require(_amount != rewardRules[_id].amount, 'IS_EQUAL');

        rewardRules[_id].poll = _createRewardRulePoll(_id, _amount);
    }

    /**
     * @dev Creates a reward claim for a rule.
     * @param _id Reference id of the rule
     */
    function claimReward(uint256 _id) public onlyMember {
        require(rewardRules[_id].state == RewardRuleState.Enabled, 'IS_NOT_ENABLED');

        RewardPoll reward = _createRewardPoll(rewardRules[_id].amount, msg.sender);

        rewards.push(reward);
        rewardsOf[msg.sender].push(reward);
    }

    /**
     * @dev Creates a custom reward proposal.
     * @param _amount Size of the reward
     * @param _beneficiary Address of the beneficiary
     */
    function proposeReward(uint256 _amount, address _beneficiary) public {
        require(isMember(_beneficiary), 'IS_NOT_MEMBER');
        require(_amount > 0, 'IS_NEGATIVE');

        RewardPoll reward = _createRewardPoll(_amount, _beneficiary);

        rewards.push(reward);
        rewardsOf[_beneficiary].push(reward);
    }

    /**
     * @dev Starts a reward poll and stores the reward.
     * @param _amount Size of the reward
     * @param _beneficiary Address of the receiver of the reward
     */
    function _createRewardPoll(uint256 _amount, address _beneficiary) internal returns (RewardPoll) {
        RewardPoll poll = new RewardPoll(_beneficiary, _amount, rewardPollDuration, address(this), address(token));

        emit RewardPollCreated(address(poll));

        return poll;
    }

    /**
     * @dev Starts a reward rule poll and stores the address of the poll.
     * @param _id Referenced reward rule
     * @param _amount Size of the reward
     */
    function _createRewardRulePoll(uint256 _id, uint256 _amount) internal returns (RewardRulePoll) {
        RewardRulePoll poll = new RewardRulePoll(_id, _amount, rewardRulePollDuration, address(this));

        emit RewardRulePollCreated(_id, _amount, msg.sender);

        return poll;
    }

    /**
     * @dev Called when poll is finished
     * @param _reward Address of reward
     * @param _agree Bool for checking the result of the poll
     */
    function onRewardPollFinish(address _reward, bool _agree) external {
        emit RewardPollFinished(_reward, _agree);
    }

    /**
     * @dev Called when poll is finished
     * @param _id id of reward rule
     * @param _amount New amount for the reward rule
     * @param _agree Bool for checking the result of the poll
     */
    function onRewardRulePollFinish(
        uint256 _id,
        uint256 _amount,
        bool _agree
    ) external {
        if (_agree) {
            rewardRules[_id].amount = _amount;

            if (_amount > 0) {
                rewardRules[_id].state = RewardRuleState.Enabled;
            } else {
                rewardRules[_id].state = RewardRuleState.Disabled;
            }
        }

        emit RewardRulePollFinished(_id, _amount, _agree);
    }

    /**
     * @dev callback called after reward is withdrawn
     * @param _reward Address of the reward
     * @param _beneficiary Receiver of the reward
     * @param _amount Size of the reward
     */
    function onWithdrawal(
        address _reward,
        address _beneficiary,
        uint256 _amount
    ) external {
        token.transfer(_beneficiary, _amount);

        Withdrawal memory w;

        w.beneficiary = _beneficiary;
        w.reward = _reward;
        w.timestamp = now;

        withdrawalsOf[_beneficiary].push(w);

        emit Withdrawn(_beneficiary, _amount);
    }
}
