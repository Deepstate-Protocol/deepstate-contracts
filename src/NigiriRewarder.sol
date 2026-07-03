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
contract NigiriRewarder is Ownable, IHook {
    using SafeTransferLib for address;

    /// @notice Pool-scoped current reward cursor for one rewarded token.
    struct Rewardee {
        uint40 orderNonce;
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

    event EngineSet(address engine);
    event RewardTokenSet(address rewardToken);
    event RewardeeUpdated(
        bytes32 poolId,
        bytes32 bookId,
        address token,
        uint40 outgoingOrderNonce,
        uint192 outgoingAmount,
        uint40 incomingOrderNonce,
        uint256 reward
    );
    event RewardsDistributed(bytes32 bookId, bytes32 order, address token, address owner, uint256 amount);

    error InvalidEngine();
    error InvalidRewardToken();
    error NotEngine();
    error NoOrderOwner();

    constructor(address owner_, address engine_, address rewardToken_) {
        _initializeOwner(owner_);
        _setEngine(engine_);
        _setRewardToken(rewardToken_);
    }

    modifier onlyEngine() {
        _onlyEngine();
        _;
    }

    function _onlyEngine() internal view {
        if (msg.sender != engine) revert NotEngine();
    }

    /// @notice Set the matching engine allowed to call `execute`.
    function setEngine(address engine_) external onlyOwner {
        _setEngine(engine_);
    }

    /// @notice Set the ERC20 paid by `distributeRewards`.
    function setRewardToken(address rewardToken_) external onlyOwner {
        _setRewardToken(rewardToken_);
    }

    /// @inheritdoc IHook
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

    function _setEngine(address engine_) private {
        if (engine_ == address(0)) revert InvalidEngine();
        engine = engine_;
        emit EngineSet(engine_);
    }

    function _setRewardToken(address rewardToken_) private {
        if (rewardToken_ == address(0)) revert InvalidRewardToken();
        rewardToken = rewardToken_;
        emit RewardTokenSet(rewardToken_);
    }
}
