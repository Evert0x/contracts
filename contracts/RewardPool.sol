// contracts/RewardPool.sol
// SPDX-License-Identifier: MIT

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
        BasePoll poll;
    }

    struct Withdrawal {
        address reward;
        address beneficiary;
    }

    RewardRule[] public rewardRules;
    RewardPoll[] public rewards;

    uint256 public rewardPollDuration;
    uint256 public rewardRulePollDuration;
    uint256 public minMembersTokensPerc;
    uint256 public minManagersTokensPerc;

    mapping(address => RewardPoll[]) public rewardsOf;
    mapping(address => Withdrawal[]) public withdrawals;

    IERC20 public token;

    /*==== IMPORTANT: Do not alter (only extend) the storage layout above this line! ====*/

    enum RewardRuleState { Enabled, Disabled }

    event Withdrawn(address indexed beneficiary, uint256 reward);

    event RewardRulePollCreated(uint256 id, uint256 proposal, address account);
    event RewardRulePollFinished(uint256 id, uint256 proposal, bool agree);

    event RewardRuleUpdated(uint256 id, RewardRuleState state, uint256 amount);

    event RewardPollCreated(address reward, bool agree);
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
     * @dev Set the duration for a reward poll.
     * @param _duration Duration in seconds
     */
    function setRewardPollDuration(uint256 _duration) public {
        require(msg.sender == owner(), 'caller is not owner');

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
     */
    function addRewardRule() public {
        require(msg.sender == owner(), 'caller is not owner');

        RewardRule memory rule;

        rule.id = rewardRules.length;
        rule.amount = 0;
        rule.state = RewardRuleState.Disabled;

        rewardRules.push(rule);
    }

    /**
     * @dev Starts a reward rule poll
     * @param _id References reward rule
     * @param _amount New size for the reward rule.
     */
    function updateRewardRule(uint256 _id, uint256 _amount) public {
        require(address(rewardRules[_id].poll) == address(0), 'another poll is running');
        require(isMember(msg.sender), 'caller is not a member');
        require(_amount >= 0, 'proposed amount is negative');
        require(_amount != rewardRules[_id].amount, 'proposed amount is equal to the current amount');

        _createRewardRulePoll(_id, _amount);
    }

    /**
     * @dev Creates a reward claim for a rule.
     * @param _id Reference id of the rule
     */
    function claimReward(uint256 _id) public {
        require(rewardRules[_id].state == RewardRuleState.Enabled, 'rule is not enabled');

        _createRewardPoll(rewardRules[_id].amount, msg.sender);
    }

    /**
     * @dev Creates a custom reward proposal.
     * @param _amount Size of the reward
     * @param _beneficiary Address of the beneficiary
     */
    function proposeReward(uint256 _amount, address _beneficiary) public {
        _createRewardPoll(_amount, _beneficiary);
    }

    /**
     * @dev Starts a reward poll and stores the reward.
     * @param _amount Size of the reward
     * @param _beneficiary Address of the receiver of the reward
     */
    function _createRewardPoll(uint256 _amount, address _beneficiary) internal {
        RewardPoll reward = new RewardPoll(_beneficiary, _amount, rewardPollDuration, address(token), address(this));

        rewards.push(reward);
        rewardsOf[_beneficiary].push(reward);
    }

    /**
     * @dev Starts a reward rule poll and stores the address of the poll.
     * @param _id Referenced reward rule
     * @param _amount Size of the reward
     */
    function _createRewardRulePoll(uint256 _id, uint256 _amount) internal {
        rewardRules[_id].poll = new RewardRulePoll(
            _id,
            _amount,
            rewardRulePollDuration,
            address(token),
            address(this),
            minMembersTokensPerc
        );

        emit RewardRulePollCreated(_id, _amount, msg.sender);
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

        Withdrawal memory withdrawal;

        withdrawal.beneficiary = _beneficiary;
        withdrawal.reward = _reward;

        withdrawals[_beneficiary].push(withdrawal);

        emit Withdrawn(_beneficiary, _amount);
    }
}