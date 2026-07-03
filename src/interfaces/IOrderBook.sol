// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Order Book Ownership View
/// @notice Minimal engine surface used by hooks to prove an order owner.
/// @dev
/// Hooks should not trust a raw nonce by itself because nonces are unique only inside one book.
/// The caller supplies the original packed order and book id; the engine derives the same global
/// owner key it uses internally.
interface IOrderBook {
    /// @notice Compute the globally unique owner key for an original order in a book.
    /// @param id Book id.
    /// @param order Original packed order node.
    /// @return Global order id used by `ownerOfOrder`.
    function orderId(bytes32 id, bytes32 order) external pure returns (bytes32);

    /// @notice Return the owner for a global order id.
    /// @param orderId Global key returned by `orderId`.
    /// @return owner Owner address, or zero if the order has been canceled/claimed.
    function ownerOfOrder(bytes32 orderId) external view returns (address);
}
