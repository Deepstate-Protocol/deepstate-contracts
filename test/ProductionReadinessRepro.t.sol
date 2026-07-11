// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {RoutingEngine} from "../src/RoutingEngine.sol";
import {QuoteMath} from "./QuoteMath.sol";

contract ProductionReadinessERC20 is ERC20 {
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

contract ProductionReadinessRoutingHarness is RoutingEngine {
    function restBookForTest(
        bytes32 id,
        uint256 nonceAndFlags,
        int32 price,
        uint160 quantity,
        bool isBid,
        address owner
    ) external returns (bytes32 restingOrder, uint32 nextNonceAfter) {
        return _restBook(id, books[id], nonceAndFlags, price, quantity, isBid, owner, false);
    }
}

contract ProductionReadinessReproTest is Test {
    uint32 internal constant MAX_ORDER_NONCE = type(uint32).max;
    bytes4 internal constant DELTA_OVERFLOW = bytes4(keccak256("DeltaOverflow()"));
    bytes4 internal constant INVALID_ORDER = bytes4(keccak256("InvalidOrder()"));

    ProductionReadinessRoutingHarness internal engine;
    ProductionReadinessERC20 internal token0;
    ProductionReadinessERC20 internal token1;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        ProductionReadinessERC20 a = new ProductionReadinessERC20("A", "A");
        ProductionReadinessERC20 b = new ProductionReadinessERC20("B", "B");
        if (address(a) < address(b)) {
            token0 = a;
            token1 = b;
        } else {
            token0 = b;
            token1 = a;
        }

        engine = new ProductionReadinessRoutingHarness();

        _fundAndApprove(alice);
        _fundAndApprove(bob);
    }

    function test_MaxTickLargeBidCanRestInsideSignedRange() public {
        uint160 quantity = uint160(type(uint128).max);
        uint256 collateral = _quoteValue(type(int32).max, quantity, true);
        assertLt(collateral, uint256(type(int256).max));
        token1.mint(bob, collateral);

        bytes32 expectedBid = _order(type(int32).max, quantity, MAX_ORDER_NONCE);

        vm.prank(bob);
        bytes32 restingBid = engine.fill(_fill(0, _order(type(int32).max, quantity, 0), true, false, false));

        bytes32 book = engine.bookId(address(token0), address(token1), 0);
        (, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 0);
        assertEq(restingBid, expectedBid);
        assertEq(bidRoot, restingBid);
        assertEq(engine.ownerOfOrder(engine.orderId(book, expectedBid)), bob);
        assertEq(token1.balanceOf(address(engine)), collateral);
    }

    function test_MixedAskAggregateAboveSignedDebitRangeReverts() public {
        uint160 totalQuantity = _restMaxTickAskOrders(3, _signedBoundaryQuantity());
        uint256 quoteAmount = _quoteValue(type(int32).max, _signedBoundaryQuantity(), false) * 3;
        assertGt(quoteAmount, uint256(type(int256).max));
        token1.mint(bob, quoteAmount);

        uint256 bobQuoteBefore = token1.balanceOf(bob);
        uint256 engineQuoteBefore = token1.balanceOf(address(engine));

        vm.prank(bob);
        vm.expectRevert(DELTA_OVERFLOW);
        engine.fill(_fill(0, _order(type(int32).max, totalQuantity, 0), true, true, false));

        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertNotEq(askRoot, bytes32(0));
        assertEq(token1.balanceOf(bob), bobQuoteBefore);
        assertEq(token1.balanceOf(address(engine)), engineQuoteBefore);
    }

    function test_MixedBidAggregateAboveSignedCreditRangeReverts() public {
        uint160 totalQuantity = _restMaxTickBidOrders(3, _signedBoundaryQuantity());
        uint256 quoteAmount = _quoteValue(type(int32).max, _signedBoundaryQuantity(), true) * 3;
        assertGt(quoteAmount, uint256(type(int256).max));
        token0.mint(alice, uint256(totalQuantity));

        vm.prank(alice);
        vm.expectRevert(DELTA_OVERFLOW);
        engine.fill(_fill(0, _order(type(int32).max, totalQuantity, 0), false, true, false));

        (, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 0);
        assertNotEq(bidRoot, bytes32(0));
    }

    function test_MaxTickLargeAskCanRestInsideSignedRange() public {
        uint160 quantity = uint160(type(uint128).max);
        uint256 proceeds = _quoteValue(type(int32).max, quantity, false);
        assertLt(proceeds, uint256(type(int256).max));
        token0.mint(alice, uint256(quantity));

        vm.prank(alice);
        bytes32 restingAsk = engine.fill(_fill(0, _order(type(int32).max, quantity, 0), false, false, false));

        bytes32 book = engine.bookId(address(token0), address(token1), 0);
        bytes32 expectedAsk = _order(type(int32).max, quantity, MAX_ORDER_NONCE);
        assertEq(restingAsk, expectedAsk);
        assertEq(engine.ownerOfOrder(engine.orderId(book, expectedAsk)), alice);
        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertEq(askRoot, restingAsk);
    }

    function test_MaxTickMixedAskSubtreeFillsBelowSignedBoundary() public {
        uint160 quantity = _successfulBoundaryQuantity();
        uint160 totalQuantity = _restMaxTickAskOrders(2, quantity);
        uint256 quoteAmount = _quoteValue(type(int32).max, quantity, false) * 2;
        assertLt(quoteAmount, uint256(type(int256).max));
        token1.mint(bob, quoteAmount);

        vm.prank(bob);
        engine.fill(_fill(0, _order(type(int32).max, totalQuantity, 0), true, true, false));

        (bytes32 askRoot,) = engine.roots(address(token0), address(token1), 0);
        assertEq(askRoot, bytes32(0));
        assertEq(token0.balanceOf(address(engine)), 0);
    }

    function test_MaxTickMixedBidSubtreeFillsBelowSignedBoundary() public {
        uint160 quantity = _successfulBoundaryQuantity();
        uint160 totalQuantity = _restMaxTickBidOrders(2, quantity);
        uint256 quoteAmount = _quoteValue(type(int32).max, quantity, true) * 2;
        assertLt(quoteAmount, uint256(type(int256).max));
        token0.mint(alice, uint256(totalQuantity));

        vm.prank(alice);
        engine.fill(_fill(0, _order(type(int32).max, totalQuantity, 0), false, true, false));

        (, bytes32 bidRoot) = engine.roots(address(token0), address(token1), 0);
        assertEq(bidRoot, bytes32(0));
        assertEq(token1.balanceOf(address(engine)), 0);
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

    function _restMaxTickAskOrders(uint256 count, uint160 quantity) internal returns (uint160 totalQuantity) {
        for (uint256 i; i < count; ++i) {
            token0.mint(alice, uint256(quantity));

            vm.prank(alice);
            engine.fill(_fill(0, _order(type(int32).max, quantity, 0), false, false, false));
            totalQuantity += quantity;
        }
    }

    function _restMaxTickBidOrders(uint256 count, uint160 quantity) internal returns (uint160 totalQuantity) {
        uint256 quotePerOrder = _quoteValue(type(int32).max, quantity, true);

        for (uint256 i; i < count; ++i) {
            token1.mint(bob, quotePerOrder);

            vm.prank(bob);
            engine.fill(_fill(0, _order(type(int32).max, quantity, 0), true, false, false));
            totalQuantity += quantity;
        }
    }

    function _signedBoundaryQuantity() internal pure returns (uint160 quantity) {
        quantity = uint160(uint256(1) << 158);
    }

    function _successfulBoundaryQuantity() internal pure returns (uint160 quantity) {
        quantity = uint160(uint256(1) << 156);
    }

    function _order(int32 price, uint160 quantity, uint32 nonce) internal pure returns (bytes32) {
        // forge-lint: disable-next-line(unsafe-typecast)
        return bytes32((uint256(uint32(price)) << 224) | (uint256(quantity) << 64) | uint256(nonce));
    }

    function _quoteValue(int32 tick, uint160 quantity, bool roundUp) internal pure returns (uint256 quoteAmount) {
        return QuoteMath.quoteValue(tick, quantity, roundUp);
    }
}
