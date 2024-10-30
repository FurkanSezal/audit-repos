### [H-1] (Incorrect signature type hash defination breaks `RankedChoice.sol::rankCandidatesBySig`)

**Description**
The EIP-712 standard, the type hash should be defined as `keccak256("rankCandidates(address[])")` in a struct. instead of `keccak256("rankCandidates(uint256[])")`. This will ensure that the signature is correctly validated.
**Impact**
This will cause the signature to be incorrectly validated. `RankedChoice.sol::rankCandidatesBySig` will not work as intented.
**Proof of Concepts**

**Recommended mitigation**
Consider changing the type hash to `keccak256("rankCandidates(address[])")` in a the struct.

### [L-1] (Lack of zero address check after ECDSA.recover causing ,when signature is invalid, ability to vote for zero address)

**Description**
The ecrecover function returns zero address when the signature is invalid.

**Impact**
Anyone can vote for zero address by calling `RankedChoice.sol::rankCandidatesBySig`

**Recommended mitigation**
Add zero address check to the `RankedChoice.sol::rankCandidatesBySig` function.

```diff

    function rankCandidatesBySig(address[] memory orderedCandidates, bytes memory signature) external {
        bytes32 structHash = keccak256(abi.encode(TYPEHASH, orderedCandidates));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
+        if(signer == address(0)){
+           revert RankedChoice__InvalidVoter();
+       }

        _rankCandidates(orderedCandidates, signer);
    }

```
