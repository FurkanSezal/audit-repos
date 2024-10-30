// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// @audit-info the IThunderLoan Contract should be implemented by ThunderContract
interface IThunderLoan {
    function repay(address token, uint256 amount) external;
}
