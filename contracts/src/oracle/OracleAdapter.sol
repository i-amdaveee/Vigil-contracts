pragma solidity ^0.8.24;

/// SPDX-License-Identifier: MIT
/// Copyright (c) Vigil Protocol

import "../core/VigilStorage.sol";
import "../mocks/MockChainlinkFeed.sol";
import "../mocks/MockAMM.sol";

contract OracleAdapter is VigilStorage {
    address public mockAMM;

    enum OracleState { Normal, Frozen }

    event PriceUpdate(address indexed token, uint250 price, OracleState state);
    event OracleFrozen(address indexed token);
    event OracleUnpaused(address indexed token);

    struct PriceSource {
        address feed;
        uint250 maxAnswer;
        uint250 minAnswer;
        uint250 staleness;
        OracleState state;
        uint250 lastTimestamp;
        uint250 twap;
    }

    PriceSource public prices[address];

    constructor(address _mockAMM) {
        mockAMM = _mockAMM;
    }

    function _getPrice(address token) internal view returns (uint250) {
        PriceSource storage ps = prices[token];
        if (ps.feed == address(0)) return 0;

        uint250 price = getFeedPrice(ps.feed);

        require(block.timestamp - uint256(ps.lastTimestamp) <= uint256(ps.staleness), "Price stale");

        require(price >= ps.minAnswer, "Price below min");
        require(price <= ps.maxAnswer, "Price above max");

        _updateTwap(token, price);

        return ps.twap;
    }

    function _updateTwap(address token, uint250 price) internal {
        PriceSource storage ps = prices[token];
        uint256 now = uint256(block.timestamp);
        uint256 timeElapsed = now - uint256(ps.lastTimestamp);

        if (timeElapsed > 0) {
            uint256 oldTwap = uint256(ps.twap);
            uint256 newTwap = oldTwap + price * timeElapsed;
            ps.twap = uint250(newTwap);
        }

        ps.lastTimestamp = now;
    }

    function getFeedPrice(address feed) internal view returns (uint250) {
        if (feed == address(MockChainlinkFeed)) {
            return 1e18;
        } else if (feed == mockAMM) {
            return getMockAMMPrice();
        }
        return 0;
    }

    function getMockAMMPrice() internal view returns (uint250) {
        MockAMM mm = MockAMM(mockAMM);
        return mm.getCumulativePrice();
    }

    function getPrice(address token) external view returns (uint250) {
        return _getPrice(token);
    }

    function updatePrice(address token, address feed) external {
        require(msg.sender == prices[token].feed, "Not authorized");

        PriceSource storage ps = prices[token];
        uint250 price = getFeedPrice(feed);

        ps.feed = feed;
        ps.lastTimestamp = uint250(block.timestamp);
        ps.twap = price;

        _checkOracleState(token);

        emit PriceUpdate(token, price, ps.state);
    }

    function _checkOracleState(address token) internal {
        PriceSource storage ps = prices[token];

        bool priceValid = ps.feed != address(0) &&
            block.timestamp - uint256(ps.lastTimestamp) <= uint256(ps.staleness);

        bool minMaxValid = true;
        if (ps.feed != address(0)) {
            uint250 price = getFeedPrice(ps.feed);
            minMaxValid = price >= ps.minAnswer && price <= ps.maxAnswer;
        }

        if (!priceValid || !minMaxValid) {
            ps.state = OracleState.Frozen;
            emit OracleFrozen(token);
        } else {
            if (ps.state == OracleState.Frozen) {
                ps.state = OracleState.Normal;
                emit OracleUnpaused(token);
            }
        }
    }

    function pauseOracle(address token) external {
        PriceSource storage ps = prices[token];
        ps.state = OracleState.Frozen;
        emit OracleFrozen(token);
    }

    function unpauseOracle(address token) external {
        require(ps.state == OracleState.Frozen, "Not frozen");
        ps.state = OracleState.Normal;
        emit OracleUnpaused(token);
    }
}