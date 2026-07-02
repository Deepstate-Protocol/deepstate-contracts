// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {RoutingEngine} from "../src/RoutingEngine.sol";

contract RoutingTestERC20 is ERC20 {
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

contract RoutingEngineHarness is RoutingEngine {
    function setNonceAndFlags(bytes32 id, uint256 nonceAndFlags) external {
        books[id].nonceAndFlags = nonceAndFlags;
    }
}

contract RoutingEngineTest is Test {
    uint40 internal constant MAX_ORDER_NONCE = type(uint40).max;

    RoutingEngineHarness internal engine;
    RoutingTestERC20 internal token0;
    RoutingTestERC20 internal token1;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        RoutingTestERC20 a = new RoutingTestERC20("A", "A");
        RoutingTestERC20 b = new RoutingTestERC20("B", "B");
        if (address(a) < address(b)) {
            token0 = a;
            token1 = b;
        } else {
            token0 = b;
            token1 = a;
        }

        engine = new RoutingEngineHarness();

        _fundAndApprove(alice);
        _fundAndApprove(bob);
    }

    function test_FirstRestInitializesActiveBook() public {
        bytes32 bid = _order(10, 5, 0);

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, bid, true, false, false));

        bytes32 id = engine.bookId(address(token0), address(token1), 0);
        assertEq(resting, _order(10, 5, MAX_ORDER_NONCE));
        assertEq(engine.nextNonce(address(token0), address(token1), 0), MAX_ORDER_NONCE - 1);
        assertEq(engine.poolEpoch(engine.poolId(address(token0), address(token1))), 0);
        assertEq(engine.ownerOfOrder(engine.orderId(id, resting)), alice);
        assertEq(token1.balanceOf(address(engine)), 50);
    }

    function test_FillRouteMatchesOldEpochAndNetsTransfers() public {
        vm.prank(alice);
        bytes32 ask = engine.fill(_fill(0, _order(10, 5, 0), false, false, false));

        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        RoutingEngine.FillParams[] memory route = new RoutingEngine.FillParams[](1);
        route[0] = _fill(0, _order(10, 3, 0), true, true, false);

        vm.prank(bob);
        engine.fillRoute(route);

        assertEq(token0.balanceOf(bob), bobToken0Before + 3);
        assertEq(token1.balanceOf(bob), bobToken1Before - 30);

        vm.prank(alice);
        (uint256 baseAmount, uint256 quoteAmount) = engine.cancel(address(token0), address(token1), 0, ask);
        assertEq(baseAmount, 2);
        assertEq(quoteAmount, 30);
    }

    function test_FillOrKillRevertsWhenRouteLegCannotFullyMatch() public {
        vm.prank(alice);
        engine.fill(_fill(0, _order(10, 1, 0), false, false, false));

        RoutingEngine.FillParams[] memory route = new RoutingEngine.FillParams[](1);
        route[0] = _fill(0, _order(10, 2, 0), true, true, true);

        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("FillOrKill()")));
        engine.fillRoute(route);
    }

    function test_RestThatExhaustsNonceRotatesAndInitializesNextBook() public {
        bytes32 oldBook = engine.bookId(address(token0), address(token1), 0);
        engine.setNonceAndFlags(oldBook, 2);

        vm.prank(alice);
        bytes32 resting = engine.fill(_fill(0, _order(10, 5, 0), true, false, false));

        bytes32 pid = engine.poolId(address(token0), address(token1));
        bytes32 newBook = engine.bookId(address(token0), address(token1), 1);

        assertEq(resting, _order(10, 5, 2));
        assertEq(engine.poolEpoch(pid), 1);
        assertEq(engine.nextNonce(address(token0), address(token1), 0), 1);
        assertEq(engine.nextNonce(address(token0), address(token1), 1), MAX_ORDER_NONCE);
        assertEq(engine.ownerOfOrder(engine.orderId(oldBook, resting)), alice);
        assertEq(engine.ownerOfOrder(engine.orderId(newBook, resting)), address(0));
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
