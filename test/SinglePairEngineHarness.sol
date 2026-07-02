// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {RoutingEngine} from "../src/RoutingEngine.sol";

contract SinglePairEngineHarness is RoutingEngine {
    struct LegacyOrderState {
        address owner;
        bool isBid;
    }

    mapping(bytes32 order => LegacyOrderState state) private legacyOrderOf;

    address public immutable BASE_TOKEN;
    address public immutable QUOTE_TOKEN;

    constructor(address baseToken_, address quoteToken_) {
        if (baseToken_ == address(0) || quoteToken_ == address(0) || baseToken_ == quoteToken_) {
            revert InvalidToken();
        }
        BASE_TOKEN = baseToken_;
        QUOTE_TOKEN = quoteToken_;
    }

    function fill(bytes32 order, bool isBid) external returns (bytes32 restingOrder) {
        FillParams memory params = FillParams({
            token0: BASE_TOKEN,
            token1: QUOTE_TOKEN,
            epoch: 0,
            order: order,
            isBid: isBid,
            noRest: false,
            fillOrKill: false
        });
        bytes memory data = abi.encodeCall(RoutingEngine.fill, (params));
        bytes memory result = _delegate(data);
        restingOrder = abi.decode(result, (bytes32));
        if (restingOrder != bytes32(0)) {
            legacyOrderOf[restingOrder] = LegacyOrderState({owner: msg.sender, isBid: isBid});
        }
    }

    function cancel(bytes32 order) external returns (uint256 baseAmount, uint256 quoteAmount) {
        bytes memory data = abi.encodeCall(RoutingEngine.cancel, (BASE_TOKEN, QUOTE_TOKEN, uint256(0), order));
        bytes memory result = _delegate(data);
        (baseAmount, quoteAmount) = abi.decode(result, (uint256, uint256));
        delete legacyOrderOf[order];
    }

    function ownerOfOrder(bytes32 order) public view override returns (address owner) {
        owner = legacyOrderOf[order].owner;
        if (owner == address(0)) owner = super.ownerOfOrder(order);
    }

    function isBidOrder(bytes32 order) public view override returns (bool isBid) {
        LegacyOrderState storage state = legacyOrderOf[order];
        if (state.owner != address(0)) return state.isBid;
        return super.isBidOrder(order);
    }

    function bidRoot() external view returns (bytes32) {
        (, bytes32 bid) = this.roots(BASE_TOKEN, QUOTE_TOKEN, 0);
        return bid;
    }

    function askRoot() external view returns (bytes32) {
        (bytes32 ask,) = this.roots(BASE_TOKEN, QUOTE_TOKEN, 0);
        return ask;
    }

    function nextNonce() external view returns (uint40) {
        return this.nextNonce(BASE_TOKEN, QUOTE_TOKEN, 0);
    }

    function tree(bytes32 node) external view returns (bytes32 leftNode, bytes32 rightNode) {
        return this.tree(this.bookId(BASE_TOKEN, QUOTE_TOKEN, 0), node);
    }

    function _delegate(bytes memory data) private returns (bytes memory result) {
        bool success;
        (success, result) = address(this).delegatecall(data);
        if (!success) {
            assembly {
                revert(add(result, 0x20), mload(result))
            }
        }
    }

    function _requireSortedTokens(address token0, address token1) internal pure override {
        if (token0 == address(0) || token1 == address(0) || token0 == token1) {
            revert InvalidToken();
        }
    }
}
