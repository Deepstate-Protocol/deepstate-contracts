// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @notice Generic top-of-book hook called by the routing engine when a canonical top buyer changes.
interface IHook {
    /// @notice Execute hook logic for a top-of-book transition.
    /// @param poolId Sorted-token pool id.
    /// @param bookId Canonical book id where the top change occurred.
    /// @param token Token whose top buyer changed.
    /// @param outgoingAmount Previous top order's live amount in `token` terms.
    /// @param incomingOrderNonce New top order nonce, or zero if the side is empty.
    function execute(bytes32 poolId, bytes32 bookId, address token, uint192 outgoingAmount, uint40 incomingOrderNonce)
        external;
}
