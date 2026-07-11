// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Top-of-Book Hook
/// @notice Generic hook called by the routing engine when a canonical top buyer changes.
/// @dev
/// Hooks are optional side effects. The routing engine calls them with `try/catch`, so hook failure
/// does not revert matching, resting, canceling, or claiming. Implementations should treat each
/// call as a best-effort signal and keep their own accounting resilient to missed or stale calls.
interface IHook {
    /// @notice Execute hook logic for a top-of-book transition.
    /// @param poolId Sorted-token pool id.
    /// @param bookId Canonical book id where the top change occurred.
    /// @param token Token whose top buyer changed; this is not necessarily a reward payout token.
    /// @param outgoingAmount Previous top order's live amount in `token` terms, or zero on first top.
    /// @param incomingOrderNonce New top order nonce, or zero if the side is empty.
    function execute(bytes32 poolId, bytes32 bookId, address token, uint160 outgoingAmount, uint32 incomingOrderNonce)
        external;
}
