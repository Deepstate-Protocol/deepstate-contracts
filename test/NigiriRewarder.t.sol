// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {NigiriRewarder} from "../src/NigiriRewarder.sol";
import {RoutingEngine} from "../src/RoutingEngine.sol";
import {IHook} from "../src/interfaces/IHook.sol";

contract RewardTestERC20 is ERC20 {
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RevertingHook is IHook {
    function execute(bytes32, bytes32, address, uint192, uint40) external pure {
        revert("bad hook");
    }
}

contract CountingHook is IHook {
    uint256 public calls;
    address public lastToken;

    function execute(bytes32, bytes32, address token, uint192, uint40) external {
        calls++;
        lastToken = token;
    }
}

contract NigiriRewarderTest is Test {
    uint40 internal constant MAX_ORDER_NONCE = type(uint40).max;

    RoutingEngine internal engine;
    NigiriRewarder internal rewarder;
    RewardTestERC20 internal token0;
    RewardTestERC20 internal token1;
    RewardTestERC20 internal rewardToken;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        RewardTestERC20 a = new RewardTestERC20("A", "A");
        RewardTestERC20 b = new RewardTestERC20("B", "B");
        if (address(a) < address(b)) {
            token0 = a;
            token1 = b;
        } else {
            token0 = b;
            token1 = a;
        }

        engine = new RoutingEngine();
        rewardToken = new RewardTestERC20("Reward", "RWD");
        rewarder = new NigiriRewarder(address(this), address(engine), address(rewardToken));
        engine.setPoolHookConfig(address(token0), address(token1), address(rewarder), true, false);

        _fundAndApprove(alice);
        _fundAndApprove(bob);
    }

    function test_RewarderAccruesWhenTopBidIsDisplacedAndDistributes() public {
        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 id = engine.bookId(address(token0), address(token1), 0);

        vm.prank(alice);
        bytes32 aliceBid = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        (uint40 firstNonce, uint64 firstStartedAt) = rewarder.rewardees(pid, address(token0));
        assertEq(firstNonce, MAX_ORDER_NONCE);
        assertEq(firstStartedAt, block.timestamp);

        vm.warp(block.timestamp + 11);

        vm.prank(bob);
        bytes32 bobBid = engine.fill(_fill(0, _order(11, 7, 0), true, false, false));
        bobBid;

        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 55);
        (uint40 secondNonce, uint64 secondStartedAt) = rewarder.rewardees(pid, address(token0));
        assertEq(secondNonce, MAX_ORDER_NONCE - 1);
        assertEq(secondStartedAt, block.timestamp);

        rewardToken.mint(address(rewarder), 55);
        rewarder.distributeRewards(id, aliceBid, address(token0));
        assertEq(rewardToken.balanceOf(alice), 55);
        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 0);
    }

    function test_SettersAndValidationBranches() public {
        vm.expectRevert(bytes4(keccak256("InvalidEngine()")));
        new NigiriRewarder(address(this), address(0), address(rewardToken));

        vm.expectRevert(bytes4(keccak256("InvalidRewardToken()")));
        new NigiriRewarder(address(this), address(engine), address(0));

        RoutingEngine replacementEngine = new RoutingEngine();
        RewardTestERC20 replacementRewardToken = new RewardTestERC20("Reward2", "RWD2");

        rewarder.setEngine(address(replacementEngine));
        assertEq(rewarder.engine(), address(replacementEngine));

        rewarder.setRewardToken(address(replacementRewardToken));
        assertEq(rewarder.rewardToken(), address(replacementRewardToken));

        vm.expectRevert(bytes4(keccak256("InvalidEngine()")));
        rewarder.setEngine(address(0));

        vm.expectRevert(bytes4(keccak256("InvalidRewardToken()")));
        rewarder.setRewardToken(address(0));
    }

    function test_OnlyEngineAndZeroBalanceDistributionBranches() public {
        vm.expectRevert(bytes4(keccak256("NotEngine()")));
        rewarder.execute(bytes32("pool"), bytes32("book"), address(token0), 1, MAX_ORDER_NONCE);

        rewarder.distributeRewards(bytes32("book"), _order(10, 1, MAX_ORDER_NONCE), address(token0));
        assertEq(rewardToken.balanceOf(alice), 0);
    }

    function test_DistributeRewardsRevertsWhenOrderOwnerIsGone() public {
        bytes32 id = engine.bookId(address(token0), address(token1), 0);

        vm.prank(alice);
        bytes32 aliceBid = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        vm.warp(block.timestamp + 11);

        vm.prank(bob);
        engine.fill(_fill(0, _order(11, 7, 0), true, false, false));

        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 55);

        vm.prank(alice);
        engine.cancel(address(token0), address(token1), 0, aliceBid);

        rewardToken.mint(address(rewarder), 55);
        vm.expectRevert(bytes4(keccak256("NoOrderOwner()")));
        rewarder.distributeRewards(id, aliceBid, address(token0));
    }

    function test_RewarderAccruesWhenTopBidIsPartiallyFilled() public {
        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 id = engine.bookId(address(token0), address(token1), 0);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        vm.warp(block.timestamp + 7);

        vm.prank(bob);
        engine.fill(_fill(0, _order(10, 2, 0), false, true, false));

        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 35);
        (uint40 nonceAfterFirstFill, uint64 startedAtAfterFirstFill) = rewarder.rewardees(pid, address(token0));
        assertEq(nonceAfterFirstFill, MAX_ORDER_NONCE);
        assertEq(startedAtAfterFirstFill, block.timestamp);

        vm.warp(block.timestamp + 3);

        vm.prank(bob);
        engine.fill(_fill(0, _order(10, 1, 0), false, true, false));

        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 44);
        (uint40 nonceAfterSecondFill, uint64 startedAtAfterSecondFill) = rewarder.rewardees(pid, address(token0));
        assertEq(nonceAfterSecondFill, MAX_ORDER_NONCE);
        assertEq(startedAtAfterSecondFill, block.timestamp);
    }

    function test_RewarderAccruesWhenTopBidFullyFillsToNextBid() public {
        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 id = engine.bookId(address(token0), address(token1), 0);

        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 5, 0), true, false, false));
        vm.prank(bob);
        engine.fill(_fill(0, _order(9, 7, 0), true, false, false));

        vm.warp(block.timestamp + 13);

        vm.prank(bob);
        engine.fill(_fill(0, _order(10, 5, 0), false, true, false));

        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 65);
        (uint40 nextNonce, uint64 nextStartedAt) = rewarder.rewardees(pid, address(token0));
        assertEq(nextNonce, MAX_ORDER_NONCE - 1);
        assertEq(nextStartedAt, block.timestamp);
    }

    function test_RewarderAccruesWhenTopBidCancelLeavesLeaf() public {
        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 id = engine.bookId(address(token0), address(token1), 0);

        vm.prank(alice);
        bytes32 aliceBid = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));
        vm.prank(bob);
        engine.fill(_fill(0, _order(9, 7, 0), true, false, false));

        vm.warp(block.timestamp + 5);

        vm.prank(alice);
        engine.cancel(address(token0), address(token1), 0, aliceBid);

        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 25);
        (uint40 nextNonce, uint64 nextStartedAt) = rewarder.rewardees(pid, address(token0));
        assertEq(nextNonce, MAX_ORDER_NONCE - 1);
        assertEq(nextStartedAt, block.timestamp);
    }

    function test_RewarderAccruesWhenTopBidCancelLeavesBranchSuccessor() public {
        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 id = engine.bookId(address(token0), address(token1), 0);

        vm.prank(alice);
        bytes32 aliceBid = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));
        vm.prank(bob);
        engine.fill(_fill(0, _order(9, 7, 0), true, false, false));
        vm.prank(bob);
        engine.fill(_fill(0, _order(8, 3, 0), true, false, false));

        vm.warp(block.timestamp + 5);

        vm.prank(alice);
        engine.cancel(address(token0), address(token1), 0, aliceBid);

        assertEq(rewarder.balances(id, address(token0), MAX_ORDER_NONCE), 25);
        (uint40 nextNonce, uint64 nextStartedAt) = rewarder.rewardees(pid, address(token0));
        assertEq(nextNonce, MAX_ORDER_NONCE - 1);
        assertEq(nextStartedAt, block.timestamp);
    }

    function test_RevertingRewardHookDoesNotBlockFill() public {
        engine.setPoolHookConfig(address(token0), address(token1), address(new RevertingHook()), true, false);

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 id = engine.bookId(address(token0), address(token1), 0);
        assertEq(engine.ownerOfOrder(engine.orderId(id, resting)), alice);
    }

    function test_InactiveSideCancelDoesNotCallHook() public {
        CountingHook hook = new CountingHook();
        engine.setPoolHookConfig(address(token0), address(token1), address(hook), true, false);

        vm.prank(alice);
        bytes32 ask = engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        vm.prank(alice);
        engine.cancel(address(token0), address(token1), 0, ask);

        assertEq(hook.calls(), 0);
        assertEq(hook.lastToken(), address(0));
    }

    function _fill(uint256 epoch, bytes32 order, bool isBid, bool noRest, bool fillOrKill)
        internal
        view
        returns (RoutingEngine.FillParams memory params)
    {
        params = RoutingEngine.FillParams({
            token0: address(token0),
            token1: address(token1),
            epoch: epoch,
            order: order,
            isBid: isBid,
            noRest: noRest,
            fillOrKill: fillOrKill
        });
    }

    function _fundAndApprove(address user) internal {
        token0.mint(user, 1_000_000);
        token1.mint(user, 1_000_000);

        vm.startPrank(user);
        token0.approve(address(engine), type(uint256).max);
        token1.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }

    function _order(uint24 price, uint192 quantity, uint40 nonce) internal pure returns (bytes32) {
        return bytes32((uint256(price) << 232) | (uint256(quantity) << 40) | uint256(nonce));
    }
}
