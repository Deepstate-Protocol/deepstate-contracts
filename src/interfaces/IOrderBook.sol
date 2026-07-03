// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @notice Minimal engine surface used by hooks to prove an order owner.
interface IOrderBook {
    function orderId(bytes32 id, bytes32 order) external pure returns (bytes32);
    function ownerOfOrder(bytes32 orderId) external view returns (address);
}
