# THX - Asset Pool

This repository holds the smart contracts used within the THX ecosystem. This document should provide more information about the configuration and governance of a asset pool. It also lists the tests for features in the contracts, explains the upgradability and references to the implemented Open Zeppelin standard contracts.

## Testing

```
# Run all tests
npm run test

# Run specific test
npm run test -- ./test/RewardPool.test.js
npm run test -- ./test/Roles.test.js
npm run test -- ./test/RewardRule.test.js
npm run test -- ./test/Reward.test.js
```

## Events

```
event Withdrawn(address indexed beneficiary, uint256 reward);
event Deposited(address indexed sender, uint256 amount);
event RewardPollCreated(uint256 id, uint256 proposal, address account);
event RewardPollFinished(uint256 id, uint256 proposal, bool agree);
event RewardUpdated(uint256 id, RewardState state, uint256 amount);
event WithdrawPollCreated(address reward);
event WithdrawPollFinished(address reward, bool agree);
```

## Configuration

-   withdrawPollDuration (default set to `0`)
-   rewardPollDuration (default set to `0`)

## Governance

Two types of polls are extended from the BasePoll contract. The polls are used to change reward sizes and approve reward proposals and withdraws.

### Withdraw Poll

An account with the `MEMBER_ROLE` can cast a vote and the default `vote.weight` will be `1`. When the member revokes its vote `vote.time` will be set to `0`.

### Reward Poll

An account with the `MANAGER_ROLE` can cast a vote and the default `vote.weight` will be `1`. When the member revokes its vote `vote.time` will be set to `0`.

## Upgrades

Make sure to have a local RPC running at `http://localhost:7545` and run `yarn serve` to execute the upgrade test script as found in the index.js file. This will display logs while updating an instance of the Asset Pool contract. Make sure to duplicate the AssetPool contract and alter the `setWithdrawPollDuration()` method as proposed in the comments of the test script.

```
// Make a change in the AssetPool contract logic (multiply the value of
// setWithdrawPollDuration method by 2), change the contract name to
// AssetPoolV2 and compile it.
```

Output should be something like this:

```
Asset Pool Admin Project is created
Asset Pool Proxy is created
Asset Pool Proxy receives 5000
Set withdrawPollDuration to 180
Adds member 0x5e0603a66bD209F13477C113dfd95B839026a2b2
A reward is proposed for 0x5e0603a66bD209F13477C113dfd95B839026a2b2 by 0xBBcCe83aa099217467E4589b553E268d50bcf2Ac
====== START PROXY LOG ======
* Asset Pool proxy address:  0x0B12C6d2C604AeF4c6148E755D53933e53d893E3
* Asset Pool implementation address: 0x11e319b4815516101f62ed059a24a83a614629dc
* Asset Pool reward poll duration:  180
* Asset Pool has stored reward:  0xda3a2b84C168a329e2ed1d491568990d56d540d9
====== END PROXY LOG ======
Asset Pool Contract is being upgraded...
Asset Pool Contract is upgraded successfully!
Set withdrawPollDuration to 180
====== START PROXY LOG ======
* Asset Pool (Upgraded) proxy address:  0x0B12C6d2C604AeF4c6148E755D53933e53d893E3
* Asset Pool (Upgraded) implementation address: 0x68be83c7aac0813684ac8b898385fbb2e3edaf1b
* Asset Pool (Upgraded) reward poll duration:  360
* Asset Pool (Upgraded) has stored reward:  0xda3a2b84C168a329e2ed1d491568990d56d540d9
====== END PROXY LOG ======
```

## OpenZeppelin

This sections described the Open Zeppelin standard contracts that are used in the THX contract layer.

### [ERC20 Token](https://docs.openzeppelin.com/contracts/3.x/erc20)

THXToken inherits all logic from this standard contract and adds some logic for integration with the Transfer Gateway. THXTokenRinkeby is the ERC20 contract that is actually deployed on Ethereum networks (Rinkeby as of today).

### [Ownable](https://docs.openzeppelin.com/contracts/3.x/access-control)

AssetPool is derived from the Ownable smart contract and inherits ownership features. Usefull when transfering ownership of a pool and restricting breaking mutations to the smart contracts. Also a necessity for the upgradability of the contract. [Read more about upgradability](#Upgrades).

### [Access Control](https://docs.openzeppelin.com/contracts/3.x/access-control)

AccessControl is used to create MEMBER_ROLE and MANAGER_ROLE. MEMBER_ROLE is used to identify members of a asset pool and allow them to claim withdrawals and vote on reward proposals.
