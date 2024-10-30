### L-1 Potential Denial of Service (DoS) in `SpookySwap::constructor` due to Gas Limit Exceedance.

**Description**

In the `SpookySwap::constructor` loop through the `treats` array, the gas limit is exceeded when the array size is large and make contract deployment fail.

```javascript
 constructor(Treat[] memory treats) ERC721("SpookyTreats", "SPKY") {
        nextTokenId = 1;
@>      for (uint256 i = 0; i < treats.length; i++) {
            addTreat(treats[i].name, treats[i].cost, treats[i].metadataURI);
        }
    }
```

Create a test folder and create a new file `Trick.t.sol` with the following code:
**Proof of Concepts**

```javascript
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../src/TrickOrTreat.sol";

contract SpookySwapTest is Test {
    SpookySwap public spookySwap;
    address public owner;
    address public user1;

    function setUp() public {
        owner = makeAddr("owner");
        vm.deal(owner, 100 ether);

        user1 = address(0x1);
        vm.deal(user1, 100 ether);

        vm.prank(owner);
        SpookySwap.Treat[] memory treats = new SpookySwap.Treat[](1);
        treats[0] = SpookySwap.Treat("Diamond Coin", 50000, "ipfs://");
        spookySwap = new SpookySwap(treats);
    }

    function test_outOfGas() public {
        vm.startPrank(user1);
        SpookySwap.Treat[] memory treats = new SpookySwap.Treat[](25000);
        for (uint256 i = 0; i < 25000; i++) {
            treats[i] = SpookySwap.Treat("Diamond Coin", 50000, "ipfs://");
        }
        vm.expectRevert(bytes(""));
        spookySwap = new SpookySwap(treats);
    }
}

```

**Recommended mitigation**
Try to reduce the number of loops in the constructor to avoid the gas limit exceedance.
Cache the length of the array in a local variable and use it in the loop.

```diff
 constructor(Treat[] memory treats) ERC721("SpookyTreats", "SPKY") {
        nextTokenId = 1;
++      uint256 length = treats.length;
--      for (uint256 i = 0; i < treats.length; i++) {
++      for (uint256 i = 0; i < length; i++) {
            addTreat(treats[i].name, treats[i].cost, treats[i].metadataURI);
        }
    }
```
