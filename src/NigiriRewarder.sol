// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IHook} from "./interfaces/IHook.sol";
import {IOrderBook} from "./interfaces/IOrderBook.sol";

/// @title Nigiri Rewarder
/// @notice Minimal reward accounting contract for canonical top buyers.
/// @dev
/// The matching engine calls `execute` when a rewarded token's top buyer changes or its live
/// amount changes. This contract accrues `amount * duration` to the outgoing order nonce, then
/// resets the pool-scoped cursor to the incoming nonce. Balances remain book-scoped because nonces
/// are unique only inside a book.
///
/// The rewarder does not decide whether an order is top of book. That decision stays inside the
/// matching engine, which has the radix tree context. The rewarder only receives a hook with:
/// pool id, book id, rewarded token, outgoing top amount, and incoming top nonce.
///
/// `token` is the token whose buyer is being rewarded, not necessarily the ERC20 paid as rewards.
/// For token0 rewards the top buyer is the best bid. For token1 rewards the top buyer is the best
/// ask, measured by the ask's live base amount because rewards are relative to the token being
/// bought in that side's accounting.
contract NigiriRewarder is Ownable, IHook {
    using SafeTransferLib for address;

    /// @notice Pool-scoped current reward cursor for one rewarded token.
    /// @dev Packed by Solidity into one storage slot.
    struct Rewardee {
        /// @notice Current top order nonce for the pool/token cursor.
        uint40 orderNonce;
        /// @notice Timestamp when the current top order became active.
        uint64 startedAt;
    }

    /// @notice Authorized matching engine that may update reward cursors.
    address public engine;

    /// @notice ERC20 paid by `distributeRewards`.
    address public rewardToken;

    /// @notice Current top-buyer rewardee per pool and rewarded token.
    mapping(bytes32 poolId => mapping(address token => Rewardee rewardee)) public rewardees;

    /// @notice Accrued rewards per book, rewarded token, and order nonce.
    mapping(bytes32 bookId => mapping(address token => mapping(uint40 orderNonce => uint256 balance))) public balances;

    /// @notice Emitted when the authorized engine is changed.
    /// @param engine Engine allowed to call `execute`.
    event EngineSet(address engine);
    /// @notice Emitted when the ERC20 paid as rewards is changed.
    /// @param rewardToken ERC20 paid by `distributeRewards`.
    event RewardTokenSet(address rewardToken);
    /// @notice Emitted after a hook accrues the previous top order and installs the next one.
    /// @param poolId Canonical sorted-token pool id.
    /// @param bookId Book id where the outgoing balance is accrued.
    /// @param token Token whose top buyer is rewarded.
    /// @param outgoingOrderNonce Previous cursor nonce, or zero when no previous cursor existed.
    /// @param outgoingAmount Previous top order amount in `token` terms.
    /// @param incomingOrderNonce New top order nonce, or zero when the side is empty.
    /// @param reward Newly accrued reward balance for `outgoingOrderNonce`.
    event RewardeeUpdated(
        bytes32 poolId,
        bytes32 bookId,
        address token,
        uint40 outgoingOrderNonce,
        uint192 outgoingAmount,
        uint40 incomingOrderNonce,
        uint256 reward
    );
    /// @notice Emitted when accrued rewards are paid to an order owner.
    /// @param bookId Book id that scopes the order nonce.
    /// @param order Original packed order node.
    /// @param token Token whose top-buyer reward balance is claimed.
    /// @param owner Order owner paid by this call.
    /// @param amount Reward token amount transferred.
    event RewardsDistributed(bytes32 bookId, bytes32 order, address token, address owner, uint256 amount);

    /// @notice Engine address is zero.
    error InvalidEngine();
    /// @notice Reward token address is zero.
    error InvalidRewardToken();
    /// @notice Caller is not the configured matching engine.
    error NotEngine();
    /// @notice The reward balance exists but the matching engine no longer reports an owner.
    error NoOrderOwner();

    /// @notice Initialize the rewarder owner, authorized engine, and payout token.
    /// @param owner_ Owner allowed to update engine and reward token configuration.
    /// @param engine_ Matching/routing engine allowed to call `execute`.
    /// @param rewardToken_ ERC20 paid by `distributeRewards`.
    constructor(address owner_, address engine_, address rewardToken_) {
        _initializeOwner(owner_);
        _setEngine(engine_);
        _setRewardToken(rewardToken_);
    }

    /// @notice Restrict a function to the configured matching engine.
    modifier onlyEngine() {
        _onlyEngine();
        _;
    }

    /// @notice Revert unless the caller is `engine`.
    function _onlyEngine() internal view {
        if (msg.sender != engine) revert NotEngine();
    }

    /// @notice Set the matching engine allowed to call `execute`.
    /// @param engine_ New authorized engine.
    function setEngine(address engine_) external onlyOwner {
        _setEngine(engine_);
    }

    /// @notice Set the ERC20 paid by `distributeRewards`.
    /// @param rewardToken_ New reward payout token.
    function setRewardToken(address rewardToken_) external onlyOwner {
        _setRewardToken(rewardToken_);
    }

    /// @inheritdoc IHook
    /// @dev
    /// If `outgoingAmount` is nonzero, the current pool/token cursor is accrued first:
    /// `reward = _calculateReward(poolId, token, outgoingAmount, block.timestamp - startedAt)`.
    /// Accrued balances are stored under `bookId` and the outgoing nonce so claims remain unique
    /// across epochs. The cursor is then overwritten with `incomingOrderNonce` and the current
    /// timestamp. A zero incoming nonce clears the cursor because the side has no top buyer.
    function execute(bytes32 poolId, bytes32 bookId, address token, uint192 outgoingAmount, uint40 incomingOrderNonce)
        external
        onlyEngine
    {
        bytes32 rewardeeSlot = _rewardeeSlot(poolId, token);
        uint256 packedRewardee;
        /// @solidity memory-safe-assembly
        assembly {
            packedRewardee := sload(rewardeeSlot)
        }

        uint256 reward;
        uint40 outgoingOrderNonce;
        if (outgoingAmount != 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            outgoingOrderNonce = uint40(packedRewardee);
            // forge-lint: disable-next-line(unsafe-typecast)
            uint64 startedAt = uint64(packedRewardee >> 40);
            if (outgoingOrderNonce != 0 && startedAt != 0) {
                // forge-lint: disable-next-line(unsafe-typecast)
                uint64 duration = uint64(block.timestamp - startedAt);
                if (duration != 0) {
                    reward = _calculateReward(poolId, token, outgoingAmount, duration);
                    if (reward != 0) balances[bookId][token][outgoingOrderNonce] += reward;
                }
            }
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 startedAtNext = uint256(uint64(block.timestamp));
        uint256 nextRewardee = incomingOrderNonce == 0 ? 0 : uint256(incomingOrderNonce) | (startedAtNext << 40);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(rewardeeSlot, nextRewardee)
        }

        emit RewardeeUpdated(poolId, bookId, token, outgoingOrderNonce, outgoingAmount, incomingOrderNonce, reward);
    }

    /// @notice Claim accrued rewards for a live order owned in the matching engine.
    /// @param bookId Book id that scopes the order.
    /// @param order Original packed order node.
    /// @param token Token whose top-buyer reward balance should be claimed.
    /// @dev
    /// The rewarder proves ownership by asking the engine for `ownerOfOrder(orderId(bookId, order))`.
    /// This prevents rewards from being claimed for a nonce after the corresponding order owner has
    /// been deleted by cancel/claim.
    function distributeRewards(bytes32 bookId, bytes32 order, address token) external {
        uint40 nonce = uint40(uint256(order));
        uint256 amount = balances[bookId][token][nonce];
        if (amount == 0) return;

        address owner = IOrderBook(engine).ownerOfOrder(IOrderBook(engine).orderId(bookId, order));
        if (owner == address(0)) revert NoOrderOwner();

        balances[bookId][token][nonce] = 0;
        rewardToken.safeTransfer(owner, amount);

        emit RewardsDistributed(bookId, order, token, owner, amount);
    }

    /// @notice Calculate rewards for an outgoing top order.
    /// @param poolId Pool being rewarded.
    /// @param token Token whose top buyer is rewarded.
    /// @param amount Live top order amount in `token` terms.
    /// @param duration Seconds the outgoing order was the recorded top buyer.
    /// @return Reward token amount to accrue.
    /// @dev Virtual so deployments can replace the simple amount-time formula.
    function _calculateReward(bytes32 poolId, address token, uint192 amount, uint64 duration)
        internal
        view
        virtual
        returns (uint256)
    {
        poolId;
        token;
        return uint256(amount) * uint256(duration);
    }

    /// @notice Compute the storage slot for `rewardees[poolId][token]`.
    /// @dev Used so `execute` can load and store the packed `Rewardee` word directly.
    function _rewardeeSlot(bytes32 poolId, address token) private pure returns (bytes32 slot) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, poolId)
            mstore(add(ptr, 0x20), rewardees.slot)
            let poolSlot := keccak256(ptr, 0x40)
            mstore(ptr, token)
            mstore(add(ptr, 0x20), poolSlot)
            slot := keccak256(ptr, 0x40)
        }
    }

    /// @notice Validate and store a new engine.
    function _setEngine(address engine_) private {
        if (engine_ == address(0)) revert InvalidEngine();
        engine = engine_;
        emit EngineSet(engine_);
    }

    /// @notice Validate and store a new reward token.
    function _setRewardToken(address rewardToken_) private {
        if (rewardToken_ == address(0)) revert InvalidRewardToken();
        rewardToken = rewardToken_;
        emit RewardTokenSet(rewardToken_);
    }
}
